//
//  Created by Maxwell Pirtle on 8/23/20
//  Copyright © 2020 Maxwell Pirtle. All rights reserved.
//
//  Abstract:
//
    
import MetalKit
import Relativity
import Accelerate.vecLib

class MSRendererCore: NSObject, MTKViewDelegate {
    
    // MARK: - Properties -
    
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
    private var state: MSRenderCoreState = .default
    
    // MARK: - Metal Lifecycle Objects -
    
    /// The device object that generates buffers, textures, etc.
    private(set) var device: MTLDevice
    
    /// The central command queue for scheduling work to the GPU
    private(set) var commandQueue: MTLCommandQueue!
    
    /// Held around as loading shaders is somewhat expensive
    private var shaderCache: MTLLibrary!
    
    /// A dispatch semaphore for restricting access to a pool of Metal buffers with
    /// storage mode `.storageModeShared` in system memory
    private let semaphore = DispatchSemaphore(value: MSConstants.framesInFlight)
    
    /// A queue to schedule command buffers in parallel
    private let workQueue = DispatchQueue(label: "MSRendererCore.DispatchQueue", qos: .userInteractive)
    
    // MARK: - Render States -
    
    /// The pipeline state of the axis render pass
    private var axisRenderPipelineState: MTLRenderPipelineState!
    
    /// The render pass descriptor describing the main rendering pass
    private var mainRenderPassDescriptor: MTLRenderPassDescriptor!

    /// The depth stencil state object describing the depth texture for perspective drawing
    private var mainPassDepthStencilState: MTLDepthStencilState!
    
    /// The vertex descriptor describing how vertex data is
    /// layed out in memory for the main render pass
    private(set) var modelInputVertexDescriptor: MTLVertexDescriptor!
    
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
        shaderCache = device.makeDefaultLibrary()
        
        setDepthStencilStates()
        setRenderPassDescriptors()
        
        do {
            try setRenderPipelineStates()
        }
        catch let error {
            throw MSRendererError(case: .MTLRenderPipeline, error: error)
        }

        // Create the other renderers
        
        //-- Particle Renderer --\\
        particleRenderer = try MSParticleRenderer(computeDevice: device, view: view, framesInFlight: framesInFlight, library: shaderCache)
        
        do {
            // Create shared resources
            uniformsCPU = MSUniforms()
            uniformsGPU = MSBuffer<MSUniforms>(device: device, options: .storageModeShared, copies: MSConstants.framesInFlight)
        }
        
        // Set the delegate of the view to the renderer
        view.delegate = self
    }
    
    // MARK: - Render State Initialization -
    
    private func setRenderPassDescriptors() {
        mainRenderPassDescriptor = view.currentRenderPassDescriptor
    }

    private func setRenderPipelineStates() throws {
        guard let library = shaderCache,
              let vertexAxis = library.makeFunction(name: "axis_vertex"),
              let fragmentAxis = library.makeFunction(name: "axis_fragment")
        else { fatalError("Expected every function in source project") }
        
        // MARK: Main Render Pass

        let renderPipelineDescriptor = MTLRenderPipelineDescriptor()

        // Initialize the vertex descriptor for the main pass
        let vertexDescriptor = MTLVertexDescriptor {
            MTLVertexAttributeDescriptor(attributeIndex: 0, format: .float3, bufferIndex: 0, offset: 0)
            MTLVertexAttributeDescriptor(attributeIndex: 1, format: .float3, bufferIndex: 0, offset: MTLVertexFormat.float3.stride)
        }
        renderPipelineDescriptor.vertexDescriptor = vertexDescriptor
        modelInputVertexDescriptor = vertexDescriptor
        
        // Axis Pass
        renderPipelineDescriptor.label = "Axis pipeline"
        renderPipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        renderPipelineDescriptor.depthAttachmentPixelFormat = .depth32Float
        renderPipelineDescriptor.vertexFunction = vertexAxis
        renderPipelineDescriptor.fragmentFunction = fragmentAxis
        
        axisRenderPipelineState = try device.makeRenderPipelineState(descriptor: renderPipelineDescriptor)
        
        // MARK: Shadow Render Pass
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
//        semaphore.wait()

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
            particleRenderer.drawParticleSimulation(commandBuffer: commandBuffer, encodingInto: renderEncoder, uniforms: uniformsGPU)
        }
        
        drawAxis:
        do {
            //---- Coordinate Axes Render ----\\
            guard state.drawsCoordinateSystem else { break drawAxis }
            
            renderEncoder.setRenderPipelineState(axisRenderPipelineState)
            
            var axisUniforms = MSUniforms(scene: scene)
            renderEncoder.setVertexBytes(&axisUniforms, length: MemoryLayout<MSUniforms>.stride, index: 1)
            
            do {
                let vertexBytes = [MSConstants.xyplane, MSConstants.xzplane, MSConstants.yzplane]
                for var axisColorIndex: ushort in 0..<3 {
                    
                    // Get a copy of the data we will again copy
                    var bytes = vertexBytes[Int(axisColorIndex)]
                    
                    renderEncoder.setVertexBytes(&bytes, length: bytes.count * MemoryLayout<simd_float3>.stride, index: 0)
                    renderEncoder.setFragmentBytes(&axisColorIndex, length: MemoryLayout<ushort>.stride, index: 1)
                    renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 12)
                }
            }
            
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
