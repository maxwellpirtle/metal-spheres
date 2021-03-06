//
//  Created by Maxwell Pirtle on 11/8/20
//  Copyright © 2020 Maxwell Pirtle. All rights reserved.
//
//  Abstract:
//  A particular kind of rendering engine that updates runs simulations of particles
//  on the GPU.

import Metal
import Relativity

final class MSParticleRenderer: NSObject, MSUniverseDelegate {

    // MARK: - Simulation State -

    /// Determines how particle data is updated in the kernel
    private var state: MSParticleRendererState = .default

    /// The collection of particles this renderer is responsible for
    /// along with their indicies into the particle buffer. This property
    /// is NOT thread safe and should not be accessed freely
    private var particles: Set<MSParticleNode> = []

    /// The number of particles that are currently being simulated
    private(set) var particlesInSimulation: Int = 0

    /// The maximum number of particle possible
    class var maximumParticlesInSimulation: Int { MSConstants.maximumParticlesInSimulation }

    /// Whether or not anything should render
    var skipRenderPass: Bool { particlesInSimulation == 0 || particles.count == 0 }
    
    /// Whether or not this simulation is paused
    var isPaused: Bool { state.isPaused }
    
    /// Whether or not particles are rendered as points
    var isRenderingParticlesAsPoints: Bool { state.pointParticles }
    
    /// Pauses the current simulation
    func pauseSimulation() { state.isPaused.negate() }
    
    /// Toggles/untoggles point particle rendering
    func togglePointParticleRendering() { state.pointParticles.negate() }

    // MARK: - Metal Internals -

    /// The compute pipeline states responsbile for running
    /// the particle simulation with more precision
    /// (All-pairs simulation)
    private let preciseComputePipelineStates: [MTLComputePipelineState]

    /// Render pipeline state to draw the primitives
    private let renderPipelineStates: [MTLRenderPipelineState]

    /// Returns a reference to the compute pipeline state to use for the current physics compute pass
    ///
    /// - Parameters:
    ///   - writePass: If we are using the dispatch to write force data into the particle buffer,
    ///     set the value to `true`
    /// - Returns:
    ///   A compute pipeline state
    private func computePipelineStateForCurrentSimulation() -> MTLComputePipelineState? {

        // Ensure that either gravity is enabled or electrostatics are enabled.
        // If both are disabled, return `nil`
        guard state.isSimulatingPhysics else { return nil }

        // The pipeline state for the particular configuration can
        // be found using the following index method
        // Gravity: F, Electrostatics: T -> 1 - 1 = 0
        // Gravity: T, Electrostatics: F -> 2 - 1 = 1
        // Gravity: T, Electrostatics: T -> 3 - 1 = 2
        let pipelineIndex = 2 * Int(CBooleanConvert: state.isGravityEnabled) + Int(CBooleanConvert: state.isElectromagnetismEnabled) - 1

        return preciseComputePipelineStates[pipelineIndex]
    }
    
    /// Returns a reference to the render pipeline state to use for the current rendering pass
    ///
    /// - Returns:
    ///   A compute render pipeline state
    private func renderPipelineStateForCurrentSimulation() -> MTLRenderPipelineState? {
        
        // The pipeline state for the particular configuration can
        // be found using the following index method
        // Point Particles: F -> 0
        // Point Particles: T -> 1
        let pipelineIndex = state.pointParticles ? 1 : 0
        
        return renderPipelineStates[pipelineIndex]
    }

    // MARK:  - Resources -

    /// The queue that is called when the GPU signals that buffer synchronization is complete
    private let synchronizationQueue = DispatchQueue(label: "MSParticleRenderer.synchronizationQueue", qos: .userInteractive)

    /// A buffer holding particle data. Allocation size: `MemoryLayout<Particle>.stride * MAX_PARTICLES`
    private var particleDataPool: MSTileBuffer<Particle>!

    /// A set of particles waiting to be added to the universe
    /// This cache can be filled if the scene is mid-render and
    /// the GPU is reading from and writing to the particle buffer
    /// backing the particle data. So that the renderer is prepared for a signal that
    /// the universe has been updated and the particles in the simulation
    /// have changed, a `MTLSharedEvent` is created and waited on by the next
    /// commamd buffer when necessary. The cache can represent the set of particles
    /// to remove or to add
    private let particleDataCache: MSParticleCache

    /// A shared event object used to temporarily synchronize the managed resources so that
    /// we can safely write into them
    private var particleSyncSharedEvent: MTLSharedEvent!

    /// Listens to a notification that a shared buffer has been written to
    private let sharedEventListener: MTLSharedEventListener

    /// Clears the particle cache by adding and removing the particles
    /// waiting in the cache and moving them into the set of particles in the simulation
    private func unsafelyResolveParticleChannel(channel particleCacheForNextAvailableFrameUpdate: MSParticleCacheChannel) {
        particles.formUnion(particleCacheForNextAvailableFrameUpdate.cachedParticleUpdate.adding)
        particles.subtract(particleCacheForNextAvailableFrameUpdate.cachedParticleUpdate.removing)
    }

    // MARK: - Initializers -

    init(computeDevice device: MTLDevice,
         view: MSSceneView,
         framesInFlight: Int,
         library: MTLLibrary) throws
    {
        // Compute Pipeline
        do {
            var preciseComputePipelineStates: [MTLComputePipelineState] = []

            try {
                // We reuse a function constants instance and write values
                // into the bind points for each iteration in the loop
                let functionConstants = MTLFunctionConstantValues()

                // All valid combinations of the simulation
                let combinations =
                    [   // Gravity = F, E = T
                        (false, true),

                        // Gravity = T, E = F
                        (true, false),

                        // Gravity = T, E = T
                        (true, true)
                    ]

                for var (isGravity, isElectricity) in combinations {
                    functionConstants.setConstantValue(&isGravity, type: .bool, index: 0)
                    functionConstants.setConstantValue(&isElectricity, type: .bool, index: 1)

                    let preciseKernel               = try library.makeFunction(name: "ThreadgroupParticleKernel", constantValues: functionConstants)
                    let preciseComputePipelineState = try device.makeComputePipelineState(function: preciseKernel)

                    // Set labels for debugging
                    preciseKernel.label = "Inverse-Square Kernel: Gravity?: \(isGravity) Elec?: \(isElectricity)"
                    preciseComputePipelineStates.append(preciseComputePipelineState)
                }
            }() // Throwing closure

            self.preciseComputePipelineStates = preciseComputePipelineStates
        }

        // Render pipeline
        do {
            let rpsd = MTLRenderPipelineDescriptor()
            rpsd.colorAttachments[0].pixelFormat = view.colorPixelFormat
            rpsd.depthAttachmentPixelFormat = view.depthStencilPixelFormat
            rpsd.fragmentFunction = library.makeFunction(name: "ParticleFragmentStage")

            let vertexDescriptor = MTLVertexDescriptor {
                MTLVertexAttributeDescriptor(attributeIndex: 0, format: .float3, bufferIndex: 0, offset: 0)
                MTLVertexAttributeDescriptor(attributeIndex: 1, format: .float3, bufferIndex: 0, offset: MTLVertexFormat.float3.stride)
            }
            rpsd.vertexDescriptor = vertexDescriptor
            
            // We reuse a function constants instance and write values
            // into the bind points for each iteration in the loop
            let functionConstants = MTLFunctionConstantValues()
            var renderPipelineStates: [MTLRenderPipelineState] = []
            
            try {
                
                // All valid combinations of the simulation
                let combinations =
                    [   // Point = false
                        false,
                        
                        // Point = true
                        true,
                    ]
                
                for var renderParticlesAsPoints in combinations {
                    functionConstants.setConstantValue(&renderParticlesAsPoints, type: .bool, index: 2)
                    
                    // Try to create the specialized vertex function and attach it to the descriptor
                    let vertexFunction = try library.makeFunction(name: "ParticleVertexStage", constantValues: functionConstants)
                    vertexFunction.label = "Particle vertex function. Point?: \(renderParticlesAsPoints)"
                    rpsd.label = "MSParticleRenderer Render Pipeline -> Points? \(renderParticlesAsPoints)"
                    rpsd.vertexFunction = vertexFunction
                    
                    if renderParticlesAsPoints { rpsd.vertexDescriptor = nil }
                    
                    let renderPipelineState = try device.makeRenderPipelineState(descriptor: rpsd)
                    renderPipelineStates.append(renderPipelineState)
                }
                
            }() // Throwing closure
            
            self.renderPipelineStates = renderPipelineStates
        }

        // Metal objects
        do {
            // We can read and write from the particle buffer, but should not do so for the force buffer; hence the storage modes described.
            // NOTE: Implicitly tracked resources
            particleDataPool        = .init(device: device, options: .storageModeManaged, length: Self.maximumParticlesInSimulation * MemoryLayout<Particle>.stride)
            
            // Synchronizing the CPU/GPU
            particleSyncSharedEvent = device.makeSharedEvent()
            sharedEventListener     = MTLSharedEventListener(dispatchQueue: synchronizationQueue)

            // Debug names
            particleDataPool.label               = "Particle Simulation Data"
            particleSyncSharedEvent.label        = "CPU Managed Buffer Safe Access Shared Event"
        }

        // Particle cache
        do {
            // In the worst case scenario, we are adding particle data when have 3 frames
            // full. Therefore, we add one more just in case since we will wait on the
            // GPU anyway
            let channels = framesInFlight + 1
            particleDataCache = MSParticleCache(channels: channels)
        }
    }

    // MARK: - Metal Resource Management -

    private func encodeSynchronizeManagedBuffers(_ commandBuffer: MTLCommandBuffer) {
        guard let blitEncoder = commandBuffer.makeBlitCommandEncoder() else
        {
            fatalError("Resource with `storageModeManaged` not properly synchronized: blit command encoder unexpectedly not created. Undefined behavior expected.")
        }

        blitEncoder.label = "Synchronize Managed Particle Data Buffers"
        blitEncoder.synchronize(resource: particleDataPool.refreshedBuffer)
        blitEncoder.endEncoding()
    }

    private func unsafelyReadGPUParticleBuffer() {
        // The data stored in the managed particle buffer is read and indexed into using the indicies
        // associated with each particle. The physical state is promptly updated
        particleDataPool.unsafelyRead(capacity: MSParticleRenderer.maximumParticlesInSimulation) { (contents: UnsafePointer<Particle>) in
            particles.enumerated().forEach { wrappedParticle in
                wrappedParticle.element.physicalState.updateState(contents[wrappedParticle.offset])
            }
        }
    }

    private func unsafelyWriteParticleDataIntoGPUBuffers() {
        do {
            let entireBuffer = 0..<particles.count * MemoryLayout<Particle>.stride

            var kernelData = particles.map { $0.physicalState.kernelState }
            particleDataPool.unsafelyWrite(&kernelData)
            particleDataPool.didModifyRange(entireBuffer)
        }
    }
    
    /// Called just before the command buffer is committed on the main thread in `MSRendererCore`
    func willCommitCommandBuffer(_ commandBuffer: MTLCommandBuffer) {
        particleDataPool.exchangeReadWriteAssigment()
    }

    // MARK: - Simulation -

    func particle(_ particle: MSParticleNode, wasAddedToUniverse scene: MSScene) {

        // If a new particle is added to the universe, add the particle to the cache
        // to be written into in the next frame
        let particleCacheForNextAvailableFrameUpdate = particleDataCache.currentChannel()!
        particleCacheForNextAvailableFrameUpdate.add(particle)
    }

    func particle(_ particle: MSParticleNode, wasRemovedFromUniverse scene: MSScene) {

        // If a new particle was removed from the universe, add the particle to the cache
        // to be removed from in the next frame
        let particleCacheForNextAvailableFrameUpdate = particleDataCache.currentChannel()!
        particleCacheForNextAvailableFrameUpdate.remove(particle)
    }

    func runInverseSquareSimulation(writingInto commandBuffer: MTLCommandBuffer,
                                    uniforms: MSBuffer<MSUniforms>)
    {
        // First, we create a new `MTLComputeCommandEncoder` and encode two thread dispatches
        guard let computePipelineState = computePipelineStateForCurrentSimulation() else { return }
        
        // Next, we ensure that the number of particles in the simulation is a multiple of the thread
        // execution width of the given device. This ensures that the GPU computations are effecient.
        // Without this assumption, we could not ensure that any given thread in a dispatch was reading
        // proper values
        guard particlesInSimulation.isMultiple(of: computePipelineState.threadExecutionWidth) else {
            fatalError("Particles cannot be evenly split into occupied simdgroups. Severe computational costs are associated with such situations on the GPU")
        }
        
        guard let computeEncoder = commandBuffer.makeComputeCommandEncoder() else { return }
        computeEncoder.pushDebugGroup("MSParticleRenderer Compute Pass")
        computeEncoder.label = "Inverse Simulation Compute Pass"
        computeEncoder.setComputePipelineState(computePipelineState)

        // Determine the size of a dispatch given the execution width of the pipeline state
        // as well as the size of a threadgroup. In macOS, the maxmimum number of threads in
        // a single threadgroup is 1024, whereas in iOS/tvOS that number is lower (256)
        let threadTileMemoryShare = MemoryLayout<ThreadgroupParticle>.stride
        let threadgroupWidth = computePipelineState.threadExecutionWidth
        let threadgroupHeight = computePipelineState.maxTotalThreadsPerThreadgroup(threadgroupMemoryPerThread: threadTileMemoryShare) / threadgroupWidth
        let threadsPerThreadgroup = MTLSize(width: threadgroupWidth, height: threadgroupHeight, depth: 1)
        let threadsInThreadgroup = threadsPerThreadgroup.totalThreads
        let threadgroupMemoryAllocationLength = threadsInThreadgroup * threadTileMemoryShare

        // Calculate the size of the grid. We place 10 times a simdgroup width of particles in any row
        // as a maximum, giving us more than enough room to operate
        let particlesInDispatch = UInt(particlesInSimulation)
        let rows = max(particlesInSimulation / threadgroupWidth, threadgroupHeight)
        let dispatchSize = MTLSize(width: threadgroupWidth, height: rows, depth: 1)
        
        // Calculate the maximum index that any thread in the entire grid can reach.
        // The determination is made using the following method:
        //
        // Grid of particle data (all particles, each box represents an index into the array)
        // + ------- + + ------- +
        // |   P     | |         |
        // |   A     | |   TG1   |
        // |   R     | |         |
        // |   T     | + ------- +
        // +   I     + |         |
        // |   C     | |   TG1   |
        // |   L     | |         |
        // |   E     | + ------- +
        // |   S     | |         |
        // + ------- + |   TG1   |
        //             |         |
        //             + ------- + <--- What we are looking for
        //
        // Notice that the threadgroups may not exactly partition the array of
        // particle data. Hence, at some point the threadgroup will not be at full occupancy
        // and some simdgroups will be without work. However, in the shader, the simdgroups must
        // execute at least one more time to reach the `threadgroup_barrier()` call in the Metal Shading Langauge
        // so that the GPU doesn't stall. Hence, the maximum index is that of the array formed by overshooting the
        // particle data array with threadgroup-sized chunks and seeing where the last chunk lands (its last index)
        var maxValidThreadgroupIndex: UInt = particlesInDispatch != 0 ? particlesInDispatch - 1 : 0
        var maxThreadgroupIndex: UInt = {
            let index = UInt(threadsInThreadgroup).smallestMultiple(greaterThanOrEqualTo: particlesInDispatch)
            return index != 0 ? index - 1 : 0 // Indexes are zero based (hence, subtract 1)
        }()
        
        // Encode a thread dispatch to compute the accelerations of each of the particles. This dispatch writes into the acceleration buffer,
        // which is then used to write back into the particle buffer in a DIFFERENT dispatch. We must do this because the kernel will write
        // to EVERY particle in the dispatch, not just those in a single threadgroup. Hence, a simple `threadgroup_barrier`
        // call in the shading langauge is insufficient to prevent undefined behavior
        computeEncoder.setBytes(&maxValidThreadgroupIndex, length: MemoryLayout<UInt>.stride, index: 0)
        computeEncoder.setBytes(&maxThreadgroupIndex, length: MemoryLayout<UInt>.stride, index: 1)
        computeEncoder.setBuffer(particleDataPool.referenceBuffer, offset: 0, index: 2)
        computeEncoder.setBuffer(particleDataPool.refreshedBuffer, offset: 0, index: 3)
        computeEncoder.setThreadgroupMemoryLength(threadgroupMemoryAllocationLength, index: 0)
        computeEncoder.dispatchThreads(dispatchSize, threadsPerThreadgroup: threadsPerThreadgroup)
        computeEncoder.popDebugGroup()
        computeEncoder.endEncoding()

        // Since we have modified a resource with `.storageModeManaged` on the GPU,
        // we must encode a blit pass to ensure the contents are well-defined on the CPU
        encodeSynchronizeManagedBuffers(commandBuffer)

        // We access the contents of the current channel that is waiting
        // to be scheduled to the GPU. Then, at the end of the function,
        // we make a call to `dispatchPendingChannel()` to ensure that the channel
        // is not reused until the CPU is done with it on another thread
        if let particleCacheForFrame = particleDataCache.pendingChannel {
            defer { particleDataCache.dispatchPendingChannel() }
            
            // In future encodings, we need to ensure that we have the correct number of threads
            // in our dispatches to ensure memory isn't being overwritten and to ensure that
            // particles with zeroed out or undefined values are not overwritten
            particlesInSimulation += particleCacheForFrame.particleChange
            
            // Get the value currently set for the shared event. This is important as the
            // the value must increase monotonically for future frames
            let value = particleSyncSharedEvent.signaledValue
            
            particleSyncSharedEvent.notify(sharedEventListener, atValue: value + 1) { [unowned self, particleCacheForFrame] event, value in

                // Synchronize the GPU/CPU representation of the world
                unsafelyReadGPUParticleBuffer()

                // Write these values to the buffer
                unsafelyResolveParticleChannel(channel: particleCacheForFrame)
                unsafelyWriteParticleDataIntoGPUBuffers()

                // Free the channel of its contents for reuse
                // We note that we do not need to call this
                // from the main thread because the particle
                // cache's properties are EXPECTED to remain
                // untouched until given the all-clear
                particleCacheForFrame.safelyClearCache()
                
                // Continue on
                event.signaledValue += 1
            }
            
            // Signal the CPU when the buffer synchronization happens
            commandBuffer.encodeSignalEvent(particleSyncSharedEvent, value: value + 1)
            commandBuffer.encodeWaitForEvent(particleSyncSharedEvent, value: value + 2)
        }
    }

    func drawParticleSimulation(commandBuffer: MTLCommandBuffer,
                                encodingInto renderEncoder: MTLRenderCommandEncoder,
                                uniforms: MSBuffer<MSUniforms>)
    {
        // If there is nothing to render, end early
        guard !skipRenderPass, let renderPipelineState = renderPipelineStateForCurrentSimulation() else { return }

        renderEncoder.pushDebugGroup("Particle rendering")
        renderEncoder.label = "Render particles encoder (instanced)"
        renderEncoder.setRenderPipelineState(renderPipelineState)
        
        if state.pointParticles { // Particles
            renderEncoder.setVertexBuffer(uniforms.dynamicBuffer, offset: 0, index: 1)
            renderEncoder.setVertexBuffer(particleDataPool.refreshedBuffer, offset: 0, index: 2)
            renderEncoder.drawPrimitives(type: .point,
                                         vertexStart: 0,
                                         vertexCount: particlesInSimulation,
                                         instanceCount: 1)
        }
        else { // Spheres

            let sharedModel = particles.first!.model!

            for mesh in sharedModel.meshes {
                for vb in mesh.mtkMesh.vertexBuffers {
                    renderEncoder.setVertexBuffer(vb.buffer, offset: 0, index: 0)
                    renderEncoder.setVertexBuffer(uniforms.dynamicBuffer, offset: 0, index: 1)
                    renderEncoder.setVertexBuffer(particleDataPool.refreshedBuffer, offset: 0, index: 2)

                    for submesh in mesh.submeshes {
                        let mtkSubmesh = submesh.mtkSubmesh!
                        renderEncoder.drawIndexedPrimitives(type: .triangle,
                                                            indexCount: mtkSubmesh.indexCount,
                                                            indexType: mtkSubmesh.indexType,
                                                            indexBuffer: mtkSubmesh.indexBuffer.buffer,
                                                            indexBufferOffset: mtkSubmesh.indexBuffer.offset,
                                                            instanceCount: particlesInSimulation)
                    }
                }
            }
        }
        renderEncoder.popDebugGroup()
    }
}
