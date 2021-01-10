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
    
    /// The amount of time between frames (1/60 of a second expected)
    constant constexpr float simulation_time_step_size = 0.016666666667f;
}

#pragma mark - Physics Kernel -

// All-pairs simulation O(n^2)

kernel void allPairsKernel(constant uint &particleCount             [[ buffer(0) ]],
                           
                           /// The pool of particle data we read from in this pass
                           const device Particle *particleData      [[ buffer(1) ]],
                           
                           /// The force acting on each of the particles. A value corresponds to
                           /// a force on the particle with the same index
                           device float3 *forces                    [[ buffer(2) ]],
                           
                           const ushort2 threadPos                  [[ thread_position_in_grid ]],
                           const ushort2 threadsPerGrid             [[ threads_per_grid ]])
{
    // Used to index into the array of particle data
    const ushort threadIndex { static_cast<ushort>(threadPos.x + threadsPerGrid.x * threadPos.y) };
    
    // Ensure we are not overridding memory (if we have n particle,
    // than the maximum index is one less than the number of particles take 1)
    // Out of bounds reads to a buffer are ignored
    if (particleCount - 1 < threadIndex) return;
    
    // Calculate the force on the object by summing
    // the contributions of every other particle
    device float3 &totalForce { forces[threadIndex] };
    const device Particle &particle { particleData[threadIndex] };
    
    // Zero out whatever value was there
    totalForce = float3(0.0, 0.0, 0.0);
    
    for (int i = 0; static_cast<uint>(i) < particleCount; i++) {
        
        // Do not compare a particle with itself
        if (threadIndex == i) continue;
        
        if (simulateGravity)
            totalForce += PhysicsCompute::newtonGravitationalForceOn(particle, particleData[i]);
        
        if (simulateElectrostatics)
            totalForce += PhysicsCompute::electrostaticForceOn(particle, particleData[i]);
    }
}

kernel void allPairsForceUpdate(constant uint &particleCount             [[ buffer(0) ]],
                                
                                /// The pool of particle data we write to in this pass
                                device Particle *particleData            [[ buffer(1) ]],
                                
                                /// The force acting on each of the particles. A value corresponds to
                                /// a force on the particle with the same index
                                const device float3 *forces              [[ buffer(2) ]],
                                
                                const ushort2 threadPos                  [[ thread_position_in_grid ]],
                                const ushort2 threadsPerGrid             [[ threads_per_grid ]])
{
    // Used to index into the array of particle data
    const ushort threadIndex { static_cast<ushort>(threadPos.x + threadsPerGrid.x * threadPos.y) };
    
    // Ensure we are not overridding memory (if we have n particles,
    // than the maximum index is one less than the number of particles take 1)
    // Out of bounds reads to a buffer are ignored
    if (particleCount - 1 < threadIndex) return;
    
    // Moving forward in time by 1/60 of a second each cycle
    PhysicsCompute::project_in_time(particleData[threadIndex], forces[threadIndex], simulation_time_step_size);
}

#ifdef __METAL_MACOS__

#pragma mark - Render Pipeline -

typedef struct {
    
    /// This position is assumed to be defined within the pre-NDC system, A.K.A model space
    float3 position [[ attribute(0) ]];
    
    /// A normal in the pre-NDC system, A.K.A model space
    float3 normal   [[ attribute(1) ]];
    
} PVertex;

typedef struct {
    
    /// Normalized position in the scene
    float4 position [[position]];
    
    /// The mass of the particle passed to the fragment. This will determine its color
    float mass;
    
    /// The charge of the particle, also determining its color
    float charge;
    
} PFragment;

vertex PFragment ParticleVertexStage(// Reading from the layout arranged through API calls
                                     const PVertex           vIn                   [[ stage_in ]],
                                     
                                     // Uniforms across the render pipeline
                                     constant MSUniforms     &uniforms             [[ buffer(1) ]],
                                     
                                     // The particles we are rendering. Each particle corresponds to a unique
                                     // instance in the draw call
                                     const device Particle   *particles            [[ buffer(2) ]],
                                     ushort                  iid                   [[ instance_id ]])
{
    // The vertex handled by this instance of the shader must have its position converted to a world frame (input as model frame)
    float3 world_pos = modelNDCToWorld3x3 * vIn.position;
    
    // Scale the particle in X, Y, and Z by its size
    world_pos *= uniforms.particleUniforms.particleSize;
    
    // Finally, translate the point by the center of the particle
    world_pos += particles[iid].position;
    
    return PFragment {
        .position = uniforms.cameraUniforms.viewProjectionMatrix * float4(world_pos, 1),
        .mass = particles[iid].mass,
        .charge = particles[iid].charge
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
