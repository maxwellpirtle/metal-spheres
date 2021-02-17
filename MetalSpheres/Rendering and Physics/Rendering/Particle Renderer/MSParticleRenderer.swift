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

    // MARK: - Metal Internals -

    /// The main renderer that is responsible for issuing commands to
    /// this renderer, sending command buffers to write into
    unowned var engine: MSRendererCore

    /// The compute pipeline states responsbile for running
    /// the particle simulation with more precision
    /// (All-pairs simulation)
    private let preciseComputePipelineStates: [MTLComputePipelineState]

    /// A kernel that writes force data into each particle
    private let preciseComputeBufferPassPipelineState: MTLComputePipelineState

    /// Render pipeline state to draw the primitives
    private let renderPipelineStates: [MTLRenderPipelineState]

    /// Returns a reference to the compute pipeline state to use for the current physics compute pass
    ///
    /// - Parameters:
    ///   - writePass: If we are using the dispatch to write force data into the particle buffer,
    ///     set the value to `true`
    /// - Returns:
    ///   A compute pipeline state
    private func computePipelineStateForCurrentSimulation(writePass: Bool = false) -> MTLComputePipelineState? {

        // Ensure that either gravity is enabled or electrostatics are enabled.
        // If both are disabled, return `nil`
        guard state.isSimulatingPhysics else { return nil }

        // Write passes return early
        if writePass { return preciseComputeBufferPassPipelineState }

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
    private var particleDataPool: MTLBuffer!
    
    /// A buffer holding the acclerations of each of the particles in the `particleDataPool`. Allocation size: `MemoryLayout<float3>.stride * MAX_PARTICLES`
    private var particleAccelerationPool: MTLBuffer!

    /// A set of particles waiting to be added to the universe
    /// This cache can be filled if the scene is mid-render and
    /// the GPU is reading from and writing to the particle buffer
    /// backing the particle data. So that the renderer is prepared for a signal that
    /// the universe has been updated and the particles in the simulation
    /// have changed, a `MTLSharedEvent` is created and waited on by the next
    /// commamd buffer when necessary. The cache can represent the set of particles
    /// to remove or to add
    private let particleDataCache: MSParticleCache

    /// A shared event object used to temporarily synchronize the managed resource so that
    /// we can safely write into it
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

    init(engine: MSRendererCore, library: MTLLibrary) throws {
        self.engine = engine
        let device = engine.device

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

                    let preciseKernel               = try library.makeFunction(name: "allPairsKernel", constantValues: functionConstants)
                    let preciseComputePipelineState = try device.makeComputePipelineState(function: preciseKernel)

                    // Set labels for debugging
                    preciseKernel.label = "Inverse-Square Kernel: Gravity?: \(isGravity) Elec?: \(isElectricity)"
                    preciseComputePipelineStates.append(preciseComputePipelineState)
                }
            }() // Throwing closure

            self.preciseComputePipelineStates = preciseComputePipelineStates

            // Kernel to write force values safely
            do {
                let forcePass = library.makeFunction(name: "allPairsForceUpdate").unsafelyUnwrapped
                forcePass.label = "Write Forces Kernel"
                preciseComputeBufferPassPipelineState = try device.makeComputePipelineState(function: forcePass)
            }
        }

        // Render pipeline
        do {
            let rpsd = MTLRenderPipelineDescriptor()
            rpsd.colorAttachments[0].pixelFormat = engine.view.colorPixelFormat
            rpsd.depthAttachmentPixelFormat = engine.view.depthStencilPixelFormat
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
            particleDataPool        = device.makeBuffer(length: Self.maximumParticlesInSimulation * MemoryLayout<Particle>.stride,        options: .storageModeManaged)
            particleAccelerationPool       = device.makeBuffer(length: Self.maximumParticlesInSimulation * MemoryLayout<simd_float3>.stride,     options: .storageModePrivate)

            // Synchronizing the CPU/GPU
            particleSyncSharedEvent = device.makeSharedEvent()
            sharedEventListener     = MTLSharedEventListener(dispatchQueue: synchronizationQueue)

            // Debug names
            particleDataPool.label        = "Particle Simulation Data"
            particleAccelerationPool.label       = "Particle Force Data"
            particleSyncSharedEvent.label = "CPU Managed Buffer Safe Access Shared Event"
        }

        // Particle cache
        do {
            // In the worst case scenario, we are adding particle data when have 3 frames
            // full. Therefore, we add one more just in case since we will wait on the
            // GPU anyway
            let channels = engine.framesInFlight + 1
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
        blitEncoder.synchronize(resource: particleDataPool)
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
        guard let computeEncoder = commandBuffer.makeComputeCommandEncoder() else { return }
        computeEncoder.pushDebugGroup("MSParticleRenderer Compute Pass")
        computeEncoder.label = "Inverse Simulation Compute Pass"
        computeEncoder.setComputePipelineState(computePipelineState)

        /// Determine the size of a dispatch given the execution width of the pipeline state
        /// as well as the size of a threadgroup. In macOS, the maxmimum number of threads in
        /// a single threadgroup is 1024, whereas in iOS/tvOS that number is lower (256)
        let threadgroupWidth = computePipelineState.threadExecutionWidth
        let threadgroupHeight = computePipelineState.maxTotalThreadsPerThreadgroup / threadgroupWidth
        let threadsPerThreadgroup = MTLSize(width: threadgroupWidth, height: threadgroupHeight, depth: 1)

        // Calculate the size of the grid. We place 10 times a simdgroup width of particles in any row
        // as a maximum, giving us more than enough room to operate
        var particlesInDispatch = UInt(particlesInSimulation)
        let particlesPerRow = threadgroupWidth * 10
        let rows = max(particlesInSimulation / particlesPerRow + 1, threadgroupHeight)
        let dispatchSize = MTLSize(width: particlesPerRow, height: rows, depth: 1)

        // Encode a thread dispatch to compute the forces on each of the particles. The dispatch writes into the force buffer,
        // which is then used to write back into the particle buffer. We must do this because the kernel will write
        // to EVERY particle in the dispatch, not just those in a single threadgroup. Hence, a simple `threadgroup_barrier`
        // call in the shading langauge is insufficient to prevent undefined behavior
        computeEncoder.setBytes(&particlesInDispatch, length: MemoryLayout<UInt>.stride, index: 0)
        computeEncoder.setBuffer(particleDataPool, offset: 0, index: 1)
        computeEncoder.setBuffer(particleAccelerationPool, offset: 0, index: 2)
        computeEncoder.dispatchThreads(dispatchSize, threadsPerThreadgroup: threadsPerThreadgroup)

        // In the first phase, we use the contents of the force buffer to write into the particle buffer.
        // If a force value is at index `i`, then this force corresponds to that acting on particle `i` in the
        // particle buffer. Note that we can use a single compute command encoder even though both kernels
        // write into and read from the same buffers because these are thread dispatches and not vertex/fragment programs
        // as described in "What's New in Metal 2" WWDC
        guard let bufferPassPiplineState = computePipelineStateForCurrentSimulation(writePass: true) else {
            preconditionFailure("Unexpectedly missing compute state to write particle force values. Execution should not be reached")
        }
        computeEncoder.setComputePipelineState(bufferPassPiplineState)
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
            renderEncoder.setVertexBuffer(particleDataPool, offset: 0, index: 2)
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
                    renderEncoder.setVertexBuffer(particleDataPool, offset: 0, index: 2)
                    
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
    
    // MARK: - Rendering State -
    
    /// Whether or not this simulation is paused
    var isPaused: Bool { state.isPaused }
    
    /// Whether or not particles are rendered as points
    var isRenderingParticlesAsPoints: Bool { state.pointParticles }
    
    /// Pauses the current simulation
    func pauseSimulation() { state.isPaused.negate() }
    
    /// Toggles/untoggles point particle rendering
    func togglePointParticleRendering() { state.pointParticles.negate() }
}
