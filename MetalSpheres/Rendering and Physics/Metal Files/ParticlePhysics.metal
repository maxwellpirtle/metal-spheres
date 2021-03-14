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
#import <metal_matrix>
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

#ifdef __METAL_IOS__
typedef struct {
    
    /// The indirect command buffer into which we encode
    /// compute pipeline commands. This ICB shares storage with the render pipeline
    /// ICB in the `PRenderICBEncoding` struct below
    command_buffer icb;
    
} PComputeICBEncoding;

kernel void EncodeParticleComputeCommands(constant PComputeICBEncoding &container [[ buffer(0) ]],
                                          device uint *index_buffer [[ buffer(1) ]])
{}
#endif

// All-pairs simulation O(n^2)

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
    if (maximumThreadIndex == 0 || !(simulateGravity || simulateElectrostatics)) return;
        
    // The index in the thread dispatch
    const uint gridIndex { static_cast<uint>(threadPos.x + threadsPerGrid.x * threadPos.y) };
    
    // Index into the shared threadgroup memory for this particular thread
    const uint threadgroupIndex { static_cast<uint>(threadgroupPos.x + threadsPerThreadgroup.x * threadgroupPos.y) };
    const uint threadsInThreadgroup { static_cast<uint>(threadsPerThreadgroup.x * threadsPerThreadgroup.y) };
    
    // Represents the current index in the threadgroup seen by this thread as it walks through the memory
    thread uint i = 0;
    
    // Represents the current threadgroup index for the threadgroup in the particle data array
    thread uint j = 0;
    
    // Represents the particle that is going to be updated by this thread
    // as well as the acceleration we will update it with
    const device Particle &particleManagedByThisThreadLastFrame = particleDataLastFrame[gridIndex];
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
    for (uint threadIndex = threadgroupIndex; threadIndex <= maximumThreadIndex; threadIndex += threadsInThreadgroup, i = 0, j++) {
        
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
            
            // If this is the iteration where only some of the threads in the threadgroup
            // are executing, we don't want to overshoot and read from threadgroup memory
            // that has not been overwritten (because it can't!)
            thread uint maxThreadgroupMemoryIndex = min(threadsInThreadgroup, maximumValidThreadIndex - j * threadsInThreadgroup);
            
            // Move through the shared threadgroup memory and read from it
            while ((simulateGravity) && i < maxThreadgroupMemoryIndex) {
                
                // To take advantage of instruction-level parallelism (ILP), we write
                // the statement 8 times, as the number of threads in any threadgroup is always a multiple of 8
                SIMD_ILP_STATEMENT(acceleration += PhysicsCompute::gravitationalFieldStrengthAt(particlePos - sharedParticleData[i].position, sharedParticleData[i]); i++);
            }
        }
        
        // Ensure all reads are complete before moving to the next loop
        threadgroup_barrier(metal::mem_flags::mem_threadgroup);
    }
    
    // Write the value to the particular particle
    device Particle &particleManagedByThisThreadNextFrame = particleDataNextFrame[gridIndex];
    
    particleManagedByThisThreadNextFrame.position = particleManagedByThisThreadLastFrame.position;
    particleManagedByThisThreadNextFrame.velocity = particleManagedByThisThreadLastFrame.velocity;
    particleManagedByThisThreadNextFrame.acceleration = acceleration;
    
    // Perform the comp.
    PhysicsCompute::project_in_time(particleManagedByThisThreadNextFrame, acceleration, simulation_time_step_size);
}

#if defined(__METAL_MACOS__)

#pragma mark - Render Pipeline -

typedef struct {
    
    /// This is the indirect command buffer object created by the device
    /// object in `device.makeIndirectCommandBuffer(descriptor:)` that we encode
    /// draw commands into on the GPU. We do this to save a considerable amount
    /// of time by pre-encoding the render coommands for thousands of particles
    /// and reusing this each frame. We only need to run more dispatches when more particles are added
    /// to the scene.
    command_buffer icb [[ id(0) ]];
    
} PRenderICBEncoding;

typedef struct {
    
    /// This position is assumed to be defined within the pre-NDC system, A.K.A model space
    float3 position [[ attribute(0), function_constant(sphericalParticles) ]];
    
    /// A normal in the pre-NDC system, A.K.A model space
    float3 normal   [[ attribute(1), function_constant(sphericalParticles)]];
    
} PVertex;

typedef struct {
    
    /// Normalized position in the scene
    float4 position  [[ position ]];
    
    /// The size of the point particle
    float point_size [[ point_size, function_constant(pointParticles) ]];
    
    /// The mass of the particle passed to the fragment. This will determine its color
    float mass;
    
    /// The charge of the particle, also determining its color
    float charge;
    
} PFragment;

kernel void EncodeParticleRenderCommands(constant PRenderICBEncoding &cpuEncodedBuffer [[ buffer(0) ]],
                                         const ushort2 threadsPerGrid                  [[ threads_per_grid ]],
                                         const ushort2 threadPos                       [[ thread_position_in_grid ]])
{
 
    // The index in the thread dispatch
    const uint gridIndex { static_cast<uint>(threadPos.x + threadsPerGrid.x * threadPos.y) };
    
    // First, create a render command that is encoded into the ICB
    render_command icb_render_command { render_command(cpuEncodedBuffer.icb, gridIndex) };
}

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
    
    return pointParticles ?
    PFragment {
        .position = uniforms.cameraUniforms.viewProjectionMatrix * float4(world_pos, 1),
        .point_size = 4.0,
        .mass = particles[index].mass,
        .charge = particles[index].charge
    } :
    PFragment {
        .position = uniforms.cameraUniforms.viewProjectionMatrix * float4(world_pos, 1),
        .mass = particles[index].mass,
        .charge = particles[index].charge
    };
}

fragment half4 ParticleFragmentStage(const PFragment pf [[ stage_in ]])
{
    constexpr half4 lightColor = half4(0.0, 0.0, 1.0, 1.0);
    constexpr half4 darkColor = half4(1.0, 0.0, 0.0, 1.0);
    const half massRatio { half(pf.mass / MAX_PARTICLE_MASS) };
    return interpolate(lightColor, darkColor, massRatio);
}
#elif __METAL_IOS__

#pragma mark - Tile-based Deferred Rendering Pipeline -

// To be implemented

struct ImageblockData {
    float image_depth   [[ raster_order_group(0) ]];
    float image_depthII [[ raster_order_group(1) ]];
};

kernel void imageblock_kernel(imageblock<ImageblockData, imageblock_layout_explicit> imageblock_explicit) {
    threadgroup_imageblock ImageblockData *data = imageblock_explicit.data(0);
}

#endif // __METAL_MACOS__
