//
//  Created by Maxwell Pirtle on 11/8/20
//  Copyright © 2020 Maxwell Pirtle. All rights reserved.
//
//  Abstract:
//  A particular kind of rendering engine that updates runs simulations of particles
//  on the GPU.

import Metal
import Relativity

final class MSParticleRenderer: NSObject, MSUniverseDelegate, MSRenderer {

    // MARK: - Simulation State -
    
    // Describes how particle data should update per-frame. Describes what forces are at play in the
    // physics pass update as well as how the particle pipeline is updated and run
    private struct State {
        /// Whether or not the simulation has been paused
        var isPaused = false
        
        /// Whether or not a physics simulation is occurring
        var isSimulatingPhysics: Bool { !isPaused && (isGravityEnabled || isElectromagnetismEnabled)  }
        
        /// Whether or not gravity is active
        var isGravityEnabled = true
        
        /// Whether or not electrostatic forces are active
        var isElectromagnetismEnabled = false
        
        /// Whether or not to draw each particle as a point as opposed to a sphere
        var pointParticles = true
        
        /// Whether or not the particle renderer is drawing via
        /// indirect command buffers encoded on the GPU
        var useIndirectCommandBuffersForRendering = true
        
        #if os(iOS) || os(tvOS)
        /// Whether or not the particle renderer is encoding compute commands via
        /// indirect command buffers encoded on the GPU. This feature is only available on iOS and tvOS
        var useIndirectCommandBuffersForCompute = false
        #endif
    }
    
    /// Describes temporary flags to communicate across control flow structures
    private struct EphemeralState {
        /// Whether or not the ICB has had its render commands encoded into it on the CPU already
        var icbHasRenderCommandsEncoded: Bool = false
    }

    /// Determines how particle data is updated in the kernel
    private var state: State = .init()
    
    /// Determines ephemeral state control flow within the particle rendering pipeline
    private var ephemeralState: EphemeralState = .init()

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

    /// The compute pipeline states responsible for running
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
    
    /// An indirect command buffer that has encoded in it the render (and possibly compute) commands
    private var indirectCommandBuffer: MTLIndirectCommandBuffer
    
    /// A buffer that stores uniform scene data read in by the GPU with an indirect command buffer
    private var indirectCommandBufferUniformDataBuffer: MTLBuffer
    
    /// A buffer that stores the current updated particle data to be used in rendering
    private var indirectCommandBufferParticleDataBuffer: MTLBuffer

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
            rpsd.supportIndirectCommandBuffers = true
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
            
            // The indirect command buffer to use in the event it begins to be used
            icb:
            do {
                let indirectCommandBufferDescriptor = MTLIndirectCommandBufferDescriptor()
                indirectCommandBufferDescriptor.commandTypes = .drawIndexed
                indirectCommandBufferDescriptor.inheritBuffers = false
                indirectCommandBufferDescriptor.inheritPipelineState = true
                indirectCommandBufferDescriptor.maxVertexBufferBindCount = 5
                indirectCommandBufferDescriptor.maxFragmentBufferBindCount = 5
                
                indirectCommandBuffer = device.makeIndirectCommandBuffer(descriptor: indirectCommandBufferDescriptor, maxCommandCount: 1, options: .storageModeManaged)!
                indirectCommandBuffer.label = "Particle renderer ICB"

                // Create the buffers the ICB references in its pre-encoded render commands
                indirectCommandBufferUniformDataBuffer = device.makeBuffer(length: 512, options: .storageModePrivate)!
                indirectCommandBufferParticleDataBuffer = device.makeBuffer(length: particleDataPool.length, options: .storageModePrivate)!
                indirectCommandBufferUniformDataBuffer.label = "Particle renderer ICB Buffer: Uniforms"
                indirectCommandBufferParticleDataBuffer.label = "Particle renderer ICB Buffer: Particles"
            }
        }

        // Particle cache
        do {
            // In the worst case scenario, we are adding particle data when have 3 frames
            // full. Therefore, we add one more just in case since we will wait on the GPU anyway
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
    
    /// Encode drawing commands into the ICB for reuse (when the `useIndirectCommandBuffersForRendering` flag is set to `true`)
    private func encodeRenderCommandsIntoICB(forModel model: MSModel) {
        let indirectRenderCommand = indirectCommandBuffer.indirectRenderCommandAt(0)

        // Go through the mesh subdivisions and encode a render command
        model.traverseMeshTree { mtkMeshBuffer in
            indirectRenderCommand.setVertexBuffer(mtkMeshBuffer.buffer, offset: mtkMeshBuffer.offset, at: 0)
            indirectRenderCommand.setVertexBuffer(indirectCommandBufferUniformDataBuffer, offset: 0, at: 1)
            indirectRenderCommand.setVertexBuffer(indirectCommandBufferParticleDataBuffer, offset: 0, at: 2)
        } submeshHandler: { submesh in
            let mtkSubmesh = submesh.mtkSubmesh!
            indirectRenderCommand.drawIndexedPrimitives(.triangle,
                                                        indexCount: mtkSubmesh.indexCount,
                                                        indexType: mtkSubmesh.indexType,
                                                        indexBuffer: mtkSubmesh.indexBuffer.buffer,
                                                        indexBufferOffset: mtkSubmesh.indexBuffer.offset,
                                                        instanceCount: particlesInSimulation,
                                                        baseVertex: 0,
                                                        baseInstance: 0)
        }
    }
    
    /// Prepares the render commands stored in the ICB for execution by querying Metal to
    /// make the resources resident in memory
    private func encodeResourceUsageForICBRendering(_ renderEncoder: MTLRenderCommandEncoder, forModel model: MSModel) {
        model.traverseMeshTree { mtkMeshBuffer in
            renderEncoder.useResource(mtkMeshBuffer.buffer, usage: .read)
            renderEncoder.useResource(indirectCommandBufferUniformDataBuffer, usage: .read)
            renderEncoder.useResource(indirectCommandBufferParticleDataBuffer, usage: .read)
        } submeshHandler: { submesh in
            let mtkSubmesh = submesh.mtkSubmesh!
            renderEncoder.useResource(mtkSubmesh.indexBuffer.buffer, usage: .read)
        }
    }
    
    
    /// Sends a message to this renderer that a new render encoding is about to commence
    /// in the central pipeline state this renderer is connected to
    func renderingWillBegin(with commandBuffer: MTLCommandBuffer, phase: MSRendererCore.RenderingPhase, uniforms: MSBuffer<MSUniforms>) {
        if state.useIndirectCommandBuffersForRendering && phase == .gBufferPass {
            // Blit data into the buffers referenced by the ICB
            let blitEncoder = commandBuffer.makeBlitCommandEncoder()!
            blitEncoder.copy(from: particleDataPool.refreshedBuffer,
                             sourceOffset: 0,
                             to: indirectCommandBufferParticleDataBuffer,
                             destinationOffset: 0,
                             size: particleDataPool.length)
            blitEncoder.copy(from: uniforms.dynamicBuffer,
                             sourceOffset: uniforms.offset,
                             to: indirectCommandBufferUniformDataBuffer,
                             destinationOffset: 0,
                             size: uniforms.dynamicBuffer.length)
            blitEncoder.endEncoding()
        }
    }
    
    /// Called just before the command buffer is committed on the main thread in `MSRendererCore`
    func willCommitCommandBuffer(_ commandBuffer: MTLCommandBuffer) {
        
        // We only flip the read-write assignment when the simulation is not paused.
        // If we were to do so when the simulation were paused, since the two particle buffers
        // hold different particle data, the models/point particles would move eradically between each
        // point as the write-assgined buffer is the one that we pass to the rendering stages
        if !isPaused { particleDataPool.exchangeReadWriteAssigment() }
        
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

    func encodeRenderCommands(into renderEncoder: MTLRenderCommandEncoder,
                              commandBuffer: MTLCommandBuffer,
                              uniforms: MSBuffer<MSUniforms>)
    {
        // If there is nothing to render, end early
        guard !skipRenderPass, let renderPipelineState = renderPipelineStateForCurrentSimulation() else { return }
        
        // Ensure that if we are using indirect command buffers that the operation is valid
        guard state.useIndirectCommandBuffersForRendering.implies(statement: renderPipelineState.supportIndirectCommandBuffers) else {
            fatalError("Ensure that the render pipeline state supports indirect commands buffers")
        }

        renderEncoder.pushDebugGroup("Particle rendering")
        renderEncoder.label = "Render particles encoder (instanced)"
        renderEncoder.setRenderPipelineState(renderPipelineState)
        
        if state.pointParticles { // Particles
            renderEncoder.setVertexBuffer(uniforms.dynamicBuffer, offset: uniforms.offset, index: 1)
            renderEncoder.setVertexBuffer(particleDataPool.refreshedBuffer, offset: 0, index: 2)
            renderEncoder.drawPrimitives(type: .point,
                                         vertexStart: 0,
                                         vertexCount: particlesInSimulation,
                                         instanceCount: 1)
        }
        else { // Spheres

            let sharedModel = particles.first!.model!
            
            if state.useIndirectCommandBuffersForRendering {
                
                if !ephemeralState.icbHasRenderCommandsEncoded {
                    encodeRenderCommandsIntoICB(forModel: sharedModel)
                    
                    // We have now encoded commands into the ICB
                    ephemeralState.icbHasRenderCommandsEncoded = true
                }
                
                encodeResourceUsageForICBRendering(renderEncoder, forModel: sharedModel)
                renderEncoder.executeCommandsInBuffer(indirectCommandBuffer, range: 0..<sharedModel.drawCallsToRender)
            }
            else {
                sharedModel.traverseMeshTree { mtkMeshBuffer in
                    renderEncoder.setVertexBuffer(mtkMeshBuffer.buffer, offset: mtkMeshBuffer.offset, index: 0)
                    renderEncoder.setVertexBuffer(uniforms.dynamicBuffer, offset: uniforms.offset, index: 1)
                    renderEncoder.setVertexBuffer(particleDataPool.refreshedBuffer, offset: 0, index: 2)
                } submeshHandler: { submesh in
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
        renderEncoder.popDebugGroup()
    }
}
