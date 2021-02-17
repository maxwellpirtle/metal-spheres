//
//  Created by Maxwell Pirtle on 11/8/20
//  Copyright © 2020 Maxwell Pirtle. All rights reserved.
//
//  Abstract:
//


// C Headers
#import "PhysicsKernel.h"
#import "MSUniforms.h"

// Metal Files
#import <metal_stdlib>
#import "PhysicsCompute.metal"
#import "Uniforms.metal"
#import "MetalExtension.metal"

using namespace metal;

#pragma mark - Constants/Function Constants -

namespace {
    constant bool simulateGravity           [[ function_constant(0) ]];
    constant bool simulateElectrostatics    [[ function_constant(1) ]];
    constant bool pointParticles            [[ function_constant(2) ]];
    constant bool sphericalParticles = !pointParticles;
    
    /// The amount of time between frames (1/60 of a second expected)
    constant constexpr float simulation_time_step_size = 0.016666666667f;
}

#pragma mark - Physics Kernel -

// All-pairs simulation O(n^2)

kernel void allPairsKernel(constant uint &particleCount             [[ buffer(0) ]],
                           
                           /// The pool of particle data we read from in this pass
                           const device Particle *particleData      [[ buffer(1) ]],
                           
                           /// The acceleration of each of the particles. A value corresponds to
                           /// an acceleration of the particle with the same index
                           device float3 *accelerations             [[ buffer(2) ]],
                           
                           const ushort2 threadPos                  [[ thread_position_in_grid ]],
                           const ushort2 threadsPerGrid             [[ threads_per_grid ]])
{
    // Index into the array of particle data
    const ushort threadIndex { static_cast<ushort>(threadPos.x + threadsPerGrid.x * threadPos.y) };
    
    // Ensure we are not overridding memory (if we have n particles,
    // then the maximum index is one less than the number of particles take 1)
    // Out of bounds reads to a buffer are ignored
    if (particleCount - 1 < threadIndex) return;
    
    // Calculate the acceleration on the particle handled by this thread by summing the contributions of every other particle
    device float3 &totalAcceleration { accelerations[threadIndex] };
    const device Particle &particle { particleData[threadIndex] };
    
    // The eletric field vector acting on the particle
    float3 electrostaticField = float3(0.0, 0.0, 0.0);
    
    // Zero out whatever value was there
    totalAcceleration = float3(0.0, 0.0, 0.0);
    
    for (int i = 0; static_cast<uint>(i) < particleCount; i++) {
        const auto relativePosition = particle.position - particleData[i].position;
        
        if (simulateGravity)
            totalAcceleration += PhysicsCompute::gravitationalFieldStrengthAt(relativePosition, particleData[i]);

        if (simulateElectrostatics)
            electrostaticField += PhysicsCompute::electricFieldStrengthAt(relativePosition, particleData[i]);
    }
    
    // Add the contribution of the electrostatic field
    if (simulateElectrostatics)
        totalAcceleration += particle.charge * electrostaticField / particle.mass; // Slow
}

kernel void allPairsForceUpdate(constant uint &particleCount             [[ buffer(0) ]],
                                
                                /// The pool of particle data we write to in this pass
                                device Particle *particleData            [[ buffer(1) ]],
                                
                                /// The acceleration of each particle. A value corresponds to
                                /// a force on the particle with the same index
                                const device float3 *accelerations       [[ buffer(2) ]],
                                
                                const ushort2 threadPos                  [[ thread_position_in_grid ]],
                                const ushort2 threadsPerGrid             [[ threads_per_grid ]])
{
    // Index into the array of particle data
    const ushort threadIndex { static_cast<ushort>(threadPos.x + threadsPerGrid.x * threadPos.y) };
    
    // Ensure we are not overridding memory (if we have n particles,
    // then the maximum index is one less than the number of particles take 1)
    // Out of bounds reads to a buffer are ignored
    if (particleCount - 1 < threadIndex) return;
    
    // Moving forward in time by 1/60 of a second each cycle
    PhysicsCompute::project_in_time(particleData[threadIndex], accelerations[threadIndex], simulation_time_step_size);
}

#ifdef __METAL_MACOS__

#pragma mark - Render Pipeline -

typedef struct {
    
    /// This position is assumed to be defined within the pre-NDC system, A.K.A model space
    float3 position [[ attribute(0), function_constant(sphericalParticles) ]];
    
    /// A normal in the pre-NDC system, A.K.A model space
    float3 normal   [[ attribute(1), function_constant(sphericalParticles)]];
    
} PVertex;

typedef struct {
    
    /// Normalized position in the scene
    float4 position [[position]];
    
    /// The mass of the particle passed to the fragment. This will determine its color
    float mass;
    
    /// The charge of the particle, also determining its color
    float charge;
    
} PFragment;

vertex PFragment ParticleVertexStage(const PVertex           vIn                   [[ stage_in, function_constant(sphericalParticles) ]],
                                     
                                     // Uniforms across the render pipeline
                                     constant MSUniforms     &uniforms             [[ buffer(1) ]],
                                     
                                     // Each particle corresponds to a unique instance in the draw call
                                     const device Particle   *particles            [[ buffer(2) ]],
                                     ushort                  vid                   [[ vertex_id, function_constant(pointParticles) ]],
                                     ushort                  iid                   [[ instance_id, function_constant(sphericalParticles) ]])
{
    // The vertex handled by this instance of the shader must have its position converted to a world frame (input as model frame)
    float3 world_pos = modelNDCToWorld3x3 * (sphericalParticles ? vIn.position : float3(0.0));
    
    // Scale the particle in X, Y, and Z by its size
    world_pos *= uniforms.particleUniforms.particleSize;
    
    // Determine the index depending on the context
    const ushort index = pointParticles ? vid : iid;

    // Translate the point by the center of the particle
    world_pos += particles[index].position;
    
    return PFragment {
        .position = uniforms.cameraUniforms.viewProjectionMatrix * float4(world_pos, 1),
        .mass = particles[index].mass,
        .charge = particles[index].charge
    };
}

fragment half4 ParticleFragmentStage(const PFragment pf [[ stage_in ]])
{
    // Hardcoded for now
    constexpr float maximumMass = 5.0;
    constexpr half4 lightColor = half4(0.0, 0.0, 1.0, 1.0);
    constexpr half4 darkColor = half4(1.0, 0.0, 0.0, 1.0);
    const half massRatio { half(pf.mass / maximumMass) };
    
    return interpolate(lightColor, darkColor, massRatio);
}

#elif __METAL_IOS__

#pragma mark - Tile-based Deferred Rendering Pipeline -

vertex void some() {
    
}

fragment void d() {
    
}

#endif // __METAL_MACOS__
