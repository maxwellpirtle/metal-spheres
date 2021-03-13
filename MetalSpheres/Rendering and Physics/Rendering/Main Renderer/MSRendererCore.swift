//
//  Created by Maxwell Pirtle on 8/23/20
//  Copyright © 2020 Maxwell Pirtle. All rights reserved.
//
//  Abstract:
//
    
import MetalKit
import Relativity

class MSRendererCore: NSObject, MTKViewDelegate {
    
    // MARK: - Properties -
    
    /// Represents the rendering state of the entire render pipeline for
    /// this applications
    private struct State {
        /// Whether or not the next frame should be captured in Xcode for debugging purposes
        var captureCommandsInXcodeNextFrame = false
    }
    
    /// Represents a particular rendering stage within the entire application render pipeline
    struct RenderingPhase: OptionSet {
        typealias RawValue = Int
        let rawValue: Int
        init(rawValue: Int) { self.rawValue = rawValue }
        
        // Main render pass render stage
        static let gBufferPass: RenderingPhase = .init(rawValue: 0)
    }
    
    /// The scene that is being rendered
    weak var scene: MSParticleScene! { view.scene as? MSParticleScene }
    
    /// The view that we are rendering into
    private(set) weak var view: MSSceneView!
    
    /// The size of the view that the renderer draws into
    private var viewSize: CGSize { view.frame.size }
    
    /// The number of frames that the CPU can write before
    /// waiting on the GPU
    var framesInFlight: Int { MSConstants.framesInFlight }
    
    /// Describes certain properties of the renderer, such as what is being drawn
    private var state: State = .init()
    
    // MARK: - Metal Lifecycle Objects -
    
    /// The device object that generates buffers, textures, etc.
    private(set) var device: MTLDevice
    
    /// The central command queue for scheduling work to the GPU
    private(set) var commandQueue: MTLCommandQueue!
    
    /// A dispatch semaphore for restricting access to a pool of Metal buffers with
    /// storage mode `.storageModeShared` in system memory
    private let semaphore = DispatchSemaphore(value: MSConstants.framesInFlight)
    
    /// A queue to schedule command buffers in parallel
    private let workQueue = DispatchQueue(label: "MSRendererCore.DispatchQueue", qos: .userInteractive)
    
    /// A debugging capture scope descriptor that brings the next render pass command
    /// encoding into the Xcode Metal Debugger view
    private lazy var debuggingCaptureDescriptor: MTLCaptureDescriptor = {
        let debuggingCaptureDescriptor = MTLCaptureDescriptor()
        debuggingCaptureDescriptor.destination = .developerTools
        debuggingCaptureDescriptor.captureObject = commandQueue
        return debuggingCaptureDescriptor
    }()
    
    // MARK: - Render States -
    
    /// The render pass descriptor describing the main rendering pass
    private var mainRenderPassDescriptor: MTLRenderPassDescriptor!

    /// The depth stencil state object describing the depth texture for perspective drawing
    private var mainPassDepthStencilState: MTLDepthStencilState!
    
    /// The vertex descriptor describing how vertex data is
    /// layed out in memory for the main render pass
    private lazy var modelInputVertexDescriptor: MTLVertexDescriptor = {
        .init {
            MTLVertexAttributeDescriptor(attributeIndex: 0, format: .float3, bufferIndex: 0, offset: 0)
            MTLVertexAttributeDescriptor(attributeIndex: 1, format: .float3, bufferIndex: 0, offset: MTLVertexFormat.float3.stride)
        }
    }()
    
    /// Returns an `MDLVertexDescriptor` based on the vertex descriptor used to render the scene
    private(set) lazy var assetsMDLVertexDescriptor: MDLVertexDescriptor = {
        .descriptor(basedOn: modelInputVertexDescriptor) {
            MDLVertexAttributeDescriptor(name: MDLVertexAttributePosition, attribute: 0)
            MDLVertexAttributeDescriptor(name: MDLVertexAttributeNormal, attribute: 1)
        }
    }()
        
    /// A triple-buffer system. Instances write to three different buffers to prevent processor stalls.
    /// Each `MemoryStore` instance holds reference to an `MSUniforms` instance
    private var uniformsGPU: MSBuffer<MSUniforms>!
    private var uniformsCPU: MSUniforms!
    
    // MARK: - Supporting Renderers -
    
    /// Writes data into particles
    private(set) var particleRenderer: MSParticleRenderer!
    
    /// Renders the coordinate frame axis at the center of the scene
    private(set) var axisRenderer: MSAxisRenderer!
    
    // MARK: - Initializers -
    
    init(view: MSSceneView) throws {
        
        // Assert that the view has a valid device
        guard let device = view.device else { preconditionFailure("View \(view) does not have an associated device object") }
        
        self.device = device
        self.view = view
        
        super.init()
        
        // Create all non-transient Metal objects
        
        commandQueue = device.makeCommandQueue()
        commandQueue.label = "Main render processing pipeline"
        
        // Load the shaders on this particular device
        let shaderCache = device.makeDefaultLibrary()!
        
        setDepthStencilStates()
        setRenderPassDescriptors()
        
        do {
            // Create the other renderers
            
            //-- Particle Renderer --\\
            particleRenderer = try MSParticleRenderer(computeDevice: device, view: view, framesInFlight: framesInFlight, library: shaderCache)
            
            //-- Axis Renderer --\\
            axisRenderer = try MSAxisRenderer(renderDevice: device, view: view, library: shaderCache)
        }
        catch let error {
            throw MSRendererError(case: .MTLRenderPipeline, error: error)
        }
        
        do {
            // Create shared resources
            uniformsCPU = MSUniforms()
            uniformsGPU = MSBuffer<MSUniforms>(device: device,
                                               options: .storageModeShared,
                                               addressSpace: .constant,
                                               copies: MSConstants.framesInFlight,
                                               shareMemory: false)
        }
        
        // Set the delegate of the view to the renderer
        view.delegate = self
    }
    
    // MARK: - Render State Initialization -
    
    private func setRenderPassDescriptors() {
        mainRenderPassDescriptor = view.currentRenderPassDescriptor
    }
    
    private func setDepthStencilStates() {
        let depthDescriptor = MTLDepthStencilDescriptor()
        depthDescriptor.label = "Depth/Stencil state object"
        depthDescriptor.depthCompareFunction = .less
        depthDescriptor.isDepthWriteEnabled = true
        mainPassDepthStencilState = device.makeDepthStencilState(descriptor: depthDescriptor)
    }
    
    // MARK: - Rendering -
    
    func draw(in view: MTKView) {
        
        // If there is nothing to draw, don't even try to wait
        guard view.currentDrawable != nil else { return }
        
        // Ensure resource writes can be accomplished
        semaphore.wait()
        
        // Check if we are doing a debug capture
        startCapturingFrameIfQueried()

        // Create a new buffer to submit to the GPU
        guard let commandBuffer = commandQueue.makeCommandBuffer() else { return }
        
        synchronization:
        do {
            //---- Shared Resource Updates ----\\
            uniformsCPU = MSUniforms(scene: scene)
            synchronizeSharedResources()
            //---- End ----\\
        }
        
        simulation:
        do {
            //---- Physics Pass ----\\
            
            particleRenderer.runInverseSquareSimulation(writingInto: commandBuffer, uniforms: uniformsGPU)
            
            //---- End ----\\
        }
        
        aboutToRender:
        do {
            particleRenderer.renderingWillBegin(with: commandBuffer, phase: .gBufferPass, uniforms: uniformsGPU)
            axisRenderer.renderingWillBegin(with: commandBuffer, phase: .gBufferPass, uniforms: uniformsGPU)
        }
        
        //---- 1st Render Pass ----\\
        guard let frameRenderPassDescriptor = view.currentRenderPassDescriptor,
              let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: frameRenderPassDescriptor) else { return }
        
        commandBuffer.label = "Frame command buffer"
        renderEncoder.label = "Core render loop encoder"
        
        // The commands into this render pass write into the same depth buffer
        renderEncoder.setDepthStencilState(mainPassDepthStencilState)
    
        render:
        do {
            
            // Tell the scene that rendering is about to begin
            let dt = 1 / Double(view.preferredFramesPerSecond)
            scene.willRender(dt)
            
            // Render particles
            particleRenderer.encodeRenderCommands(into: renderEncoder, commandBuffer: commandBuffer, uniforms: uniformsGPU)
        }
        
        drawAxis:
        do {
            //---- Coordinate Axes Render ----\\
            axisRenderer.encodeRenderCommands(into: renderEncoder, commandBuffer: commandBuffer, uniforms: uniformsGPU)
            //---- End ----\\
        }
        
        renderEncoder.endEncoding()
        //---- End 1st Render Pass ----\\
    
        //---- CPU/GPU Resource Synchronization and Frame Commit ----\\
        
        uniformsGPU.cycleToNextAvailableBuffer()
        particleRenderer.willCommitCommandBuffer(commandBuffer)
        
        // Add a scheduler to signal to the render thread execution can continue
        // The closure is explicit about its capture semantics: here, we are
        // capturing the semaphore by reference
        commandBuffer.addCompletedHandler { [semaphore] _ in
            semaphore.signal()
        }
     
        // Commit the buffer and have it present ASAP
        commandBuffer.present(view.currentDrawable!)
        commandBuffer.commit()
        
        // Stop the frame capture (if one was in progress)
        stopCapturingFrameIfNecessary()
        
        //---- End ----\\
    }
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        // Push the update to the scene so it can reconfigure itself
        scene?.viewDidResize(view as! MSSceneView, oldSize: viewSize)
    }
    
    // MARK: - Rendering State -

    /// Whether or not the particle simulation is paused
    var isPaused: Bool { particleRenderer.isPaused }
    
    /// Whether or not the simulation is rendering particles as points
    var isRenderingParticlesAsPoints: Bool { particleRenderer.isRenderingParticlesAsPoints }
    
    /// Pause/unpause the current particle simulation
    func pauseSimulation() { particleRenderer.pauseSimulation() }
    
    /// Toggles/untoggles point particle rendering
    func togglePointParticleRendering() { particleRenderer.togglePointParticleRendering() }
    
    // MARK: - Resource Synchronization -
    
    /// Synchronizes resources with `MTLStorageMode.storageModeShared` attribute
    private func synchronizeSharedResources() { uniformsGPU.unsafelyWrite(&uniformsCPU) }
    
    // MARK: - Debugging -
    
    /// Begins a capture scope if we have been flagged to do so
    private func startCapturingFrameIfQueried() {
        if state.captureCommandsInXcodeNextFrame {
            do { try MTLCaptureManager.shared().startCapture(with: debuggingCaptureDescriptor) } catch let error { assertionFailure("Could not successfully begin programmatic frame capture. Error: " + error.localizedDescription) }
        }

    }
    /// Ends the capture scope that started from a call to `startCapturingFrameIfQueried()` that was successful.
    /// Further, we assume that the flag is emphemeral (that is, for a single frame) and is thus reset with this call
    private func stopCapturingFrameIfNecessary() {
        if state.captureCommandsInXcodeNextFrame { MTLCaptureManager.shared().stopCapture() }
        
        // We've captured the frame (presumably), so we reset the flag so that
        // we don't accidentally capture another frame programmatically
        state.captureCommandsInXcodeNextFrame = false
    }
}

// MARK: - Errors -

extension MSRendererCore {
    /// Defines a set of errors that may occur when initializing an `MSRendererCore` instance
    struct MSRendererError: Error {
        
        /// What the error describes
        enum ErrorCase { case MTLRenderPipeline }
        
        let `case`: ErrorCase
        let error: Error
        var localizedDescription: String { error.localizedDescription }
    }
}
