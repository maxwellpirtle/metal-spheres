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
    
    // Compile shaders with this flag ONLY IF the program can guarantee
    // that the number of particles simulated in the scene is a multiple of
    // the simdgroup size of the GPU
    constant bool optimizeGPUExecution      [[ function_constant(3) ]];
    constant bool checkSimdgroupOutOfBounds = false;
    
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
    // Index into the array of particle and acceleration data for this particular thread
    const ushort threadIndex { static_cast<ushort>(threadPos.x + threadsPerGrid.x * threadPos.y) };
    
    // Ensure we are not overridding memory (if we have n particles,
    // then the maximum index is one less than the number of particles take 1)
    // Out of bounds reads to a buffer are ignored
    //
    // IDEALLY SET THE PARTICLE COUNT TO BE A MULTIPLE OF THE THREAD EXECUTION WIDTH
    // This will ensure coherent execution within the simdgroup, and the execution cost will
    // be limited to only to the extra registers needed to handle the `if` statement
    //
    if (checkSimdgroupOutOfBounds && particleCount - 1 < threadIndex) return;
    
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
    // Index into the array of particle and acceleration data for this particular thread
    const ushort threadIndex { static_cast<ushort>(threadPos.x + threadsPerGrid.x * threadPos.y) };
    
    // Ensure we are not overridding memory (if we have n particles,
    // then the maximum index is one less than the number of particles take 1)
    // Out of bounds reads to a buffer are ignored
    //
    // IDEALLY SET THE PARTICLE COUNT TO BE A MULTIPLE OF THE THREAD EXECUTION WIDTH
    // This will ensure coherent execution within the simdgroup, and the execution cost will
    // be limited to only to the extra registers needed to handle the `if` statement
    //
    if (checkSimdgroupOutOfBounds && particleCount - 1 < threadIndex) return;
    
    // Ensure we are not overridding memory (if we have n particles,
    // then the maximum index is one less than the number of particles take 1)
    // Out of bounds reads to a buffer are ignored. We move forward in time by 1/60 of a second each cycle
    PhysicsCompute::project_in_time(particleData[threadIndex], accelerations[threadIndex], simulation_time_step_size);
}

// All-pairs simulation O(n^2) with threadgroup memory

kernel void ThreadgroupParticleKernel(constant uint &maximumValidThreadIndex                [[ buffer(0) ]],
                                      constant uint &maximumThreadIndex                     [[ buffer(1) ]],
                                      
                                      /// The pool of particle data we read from in this pass
                                      const device Particle *particleDataLastFrame          [[ buffer(2) ]],
                                      
                                      /// The pool of particle data we write into in this pass
                                      device Particle *particleDataNextFrame                [[ buffer(3) ]],
                                      
                                      /// A shared pool of threadgroup memory that serves as a location
                                      /// to temporarily store chunks of the previous frame's particle data.
                                      /// Only the data that is relevant is stored in threadgroup memory as it is limited
                                      /// to 16KB on macOS
                                      threadgroup ThreadgroupParticle *sharedParticleData   [[ threadgroup(0) ]],
                                      
                                      const ushort2 threadgroupPos             [[ thread_position_in_threadgroup ]],
                                      const ushort2 threadPos                  [[ thread_position_in_grid ]],
                                      const ushort2 threadsPerThreadgroup      [[ threads_per_threadgroup ]],
                                      const ushort2 threadsPerGrid             [[ threads_per_grid ]])
{
    // If we have no particles to compute with, do nothing (not computationally slow as coherent execution will occur
    // since the value resides in the `constant` address space)
    if (maximumThreadIndex == 0) return;
        
    // The index in the thread dispatch
    const uint gridIndex { static_cast<ushort>(threadPos.x + threadsPerGrid.x * threadPos.y) };
    
    // Index into the shared threadgroup memory for this particular thread
    const uint threadgroupIndex { static_cast<ushort>(threadgroupPos.x + threadsPerThreadgroup.x * threadgroupPos.y) };
    const uint threadsInThreadgroup { static_cast<ushort>(threadsPerThreadgroup.x * threadsPerThreadgroup.y) };
    
    // Represents the current index in the threadgroup seen by this thread as it walks through the memory
    thread uint j = 0;
    
    // Represents the particle that is going to be updated by this thread
    // as well as the acceleration we will update it with
    const device Particle &particleManagedByThisThreadLastFrame = particleDataLastFrame[gridIndex];
    device Particle &particleManagedByThisThreadNextFrame = particleDataNextFrame[gridIndex];
    const float3 particlePos = particleManagedByThisThreadLastFrame.position;
    float3 acceleration = 0.0;
    
    // Imagine the pool of the last frame's particle and acceleration data
    // as a long line of boxes. We are indexing into this set from
    // each thread by assigning to each thread to handle any indicies in the buffer
    // whose modulus with respect to the size of the threadgroup 10 is the thread's index in threadgroup memory (if `i` is this value, we
    // are dealing with the particle at `i`, `i + threadGroupSize`, `i + 2 * threadGroupSize`, ...
    // We keep going until the root surpasses the largest index in the grid
    //
    // We initially start with the threadgroup index and increment this thread's index by the
    // size of the threadgroup
    //
    // NOTE: The for-loop condition will NOT cause divergent execution since every thread in a simdgroup will
    // return `false` at the same time as the number of particles is a multiple of the simdgroup size
    //
    // NOTE: When a simdgroup overshoots and its threads have indicies outside of the maximum index of
    // `particleCount - 1`, we STILL ITERATE AGAIN BUT DON'T COMPUTE ANYTHING. The reason we do this is to ensure
    // that every thread reaches the `threadgroup_barrier(metal::mem_flags::mem_threadgroup)` call below. Otherwise the
    // GPU will hang and the dispatch semaphore will block the main thread, causing a deadlock
    for (uint threadIndex = threadgroupIndex; threadIndex <= maximumThreadIndex; threadIndex += threadsInThreadgroup, j = 0) {
        
        // Should we do anything in this loop other than reach the barrier?
        // The flag is true if the `threadIndex` exceeds the `maximumValidIndex`. Note that
        // this then implies that EVERY THREAD IN THIS SIMDGROUP WILL ALSO HAVE AN INDEX EXCEEDING
        // THE HIGHEST AVAILABLE INDEX. Therefore, the `if` statement will not be costly (coherent execution)
        bool writeToThreadgroupMemory = threadIndex <= maximumValidThreadIndex;
        
        if (writeToThreadgroupMemory)
        {
            // Copy the data from device memory into tile memory
            const device Particle &thisThreadsCurrentThreadgroupParticle = particleDataLastFrame[threadIndex];
            sharedParticleData[threadgroupIndex] = (ThreadgroupParticle)
            {
                .mass = thisThreadsCurrentThreadgroupParticle.mass,
                .charge = thisThreadsCurrentThreadgroupParticle.charge,
                .position = thisThreadsCurrentThreadgroupParticle.position,
            };
        }
        
        // Ensure all writes are complete
        threadgroup_barrier(metal::mem_flags::mem_threadgroup);
        
        if (writeToThreadgroupMemory) {
            // Move through the shared threadgroup memory and read from it
            while ((simulateGravity) && j < threadsInThreadgroup) {
                
                // To take advantage of instruction-level parallelism (ILP), we write
                // the statement 8 times, as the number of threads in any threadgroup is always a multiple of 8
                SIMD_ILP_STATEMENT(acceleration += PhysicsCompute::gravitationalFieldStrengthAt(particlePos - sharedParticleData[j].position, sharedParticleData[j]); j++);
            }
        }
        
        // Ensure all reads are complete before moving to the next loop
        threadgroup_barrier(metal::mem_flags::mem_threadgroup);
    }
    
    // Write the value to the particular particle
    particleManagedByThisThreadNextFrame = particleManagedByThisThreadLastFrame;
    particleManagedByThisThreadNextFrame.acceleration = acceleration;
    PhysicsCompute::project_in_time(particleManagedByThisThreadNextFrame, acceleration, simulation_time_step_size);
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
