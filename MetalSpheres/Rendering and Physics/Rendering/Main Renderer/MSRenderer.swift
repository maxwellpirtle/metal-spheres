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
    weak var scene: MSScene! { view.scene }
    
    /// The view that we are rendering into
    private(set) weak var view: MTKSceneView!
    
    /// The size of the view that the renderer draws into
    private var viewSize: CGSize { view.frame.size }
    
    // MARK: - Metal Lifecycle Objects -
    
    /// The device object that generates buffers, textures, etc.
    private(set) var device: MTLDevice
    
    /// The central command queue for scheduling work to the GPU
    private var commandQueue: MTLCommandQueue!
    
    /// A dispatch semaphore for managing work
    private let semaphore = DispatchSemaphore(value: 3)
    
    /// A queue to schedule command buffers in parallel
    private let workQueue = DispatchQueue(label: "MSRendererCore.DispatchQueue", qos: .userInteractive)
    
    // MARK: - Render States -
    
    /// The render pass descriptor describing the main rendering pass
    private var mainRenderPassDescriptor: MTLRenderPassDescriptor!
    
    /// The pipeline state object describing the current state of rendering affairs for the standard render pass
    private var mainPassRenderPipelineState: MTLRenderPipelineState!
    
    /// The depth stencil state object describing the depth texture for perspective drawing
    private var mainPassDepthStencilState: MTLDepthStencilState!
    
    /// The vertex descriptor describing how vertex data is
    /// layed out in memory for the main render pass
    private(set) var mainPassVertexDescriptor: MTLVertexDescriptor!
    
    /// Returns an `MDLVertexDescriptor` based on the vertex descriptor used to render the scene
    private(set) lazy var assetsMDLVertexDescriptor: MDLVertexDescriptor = {
        .descriptor(basedOn: mainPassVertexDescriptor) {
            MDLVertexAttributeDescriptor(name: MDLVertexAttributePosition, attribute: 0)
            MDLVertexAttributeDescriptor(name: MDLVertexAttributeNormal, attribute: 1)
        }
    }()
    
    /// A triple-buffer system. Instances write to three different buffers to prevent processor stalls.
    /// Each `MemoryStore` instance holds reference to the buffers for each render pass
//    private var memoryStore: MSMemoryAllocator
    
    // MARK: - Supporting Renderers -
    
    /// Writes data into particles
    private var particleRenderer: MSParticleRenderer!
    
    // MARK: - Initializers -
    
    init(view: MTKSceneView) throws {
        
        // Assert that the view has a valid device
        guard let device = view.device else { preconditionFailure("View \(view) does not have an associated device object") }
        
        self.device = device
        self.view = view
        
//        memoryStore = MSMemoryAllocator(device: device) {
//            MSBuffer(value: 10, options: [])
//            MSBuffer(value: 10, options: [])
//            MSBuffer(value: 10, options: [])
//        }
        
        super.init()
        
        // Set up the render pass descriptors
        setRenderPassDescriptors()
        
        // Try to make the pipeline descriptor
        do {
            try setRenderPipelineStates()
        }
        catch let error {
            throw MSRendererError(case: .MTLRenderPipeline, error: error)
        }
        
        // Create the depth and stencil states
        setDepthStencilStates()
        
        // Create the command queue
        commandQueue = device.makeCommandQueue()
        
        // Set the delegate of the view to the renderer
        view.delegate = self
    }
    
    // MARK: - Render State Initialization -
    
    private func setRenderPassDescriptors() {
        mainRenderPassDescriptor = view.currentRenderPassDescriptor
    }

    private func setRenderPipelineStates() throws {
        guard let library = device.makeDefaultLibrary(),
            let vertexMain = library.makeFunction(name: "vertexMain"),
            let fragmentMain = library.makeFunction(name: "fragmentMain")
        else { fatalError(#"Expected "vertexMain" and "fragmentMain" in default library"#) }
        
        // MARK: Main Render Pass

        let renderPipelineDescriptor = MTLRenderPipelineDescriptor()
        renderPipelineDescriptor.label = "Main render pass RPD"
        renderPipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        renderPipelineDescriptor.depthAttachmentPixelFormat = .depth32Float
        renderPipelineDescriptor.vertexFunction = vertexMain
        renderPipelineDescriptor.fragmentFunction = fragmentMain
        renderPipelineDescriptor.vertexBuffers[Int(vertexUniforms.rawValue)].mutability = .immutable
        renderPipelineDescriptor.fragmentBuffers[Int(fragmentUniforms.rawValue)].mutability = .immutable

        // Initialize the vertex descriptor for the main pass
        let vertexDescriptor = MTLVertexDescriptor {
            MTLVertexAttributeDescriptor(attributeIndex: 0, format: .float3, bufferIndex: 0, offset: 0)
            MTLVertexAttributeDescriptor(attributeIndex: 1, format: .float3, bufferIndex: 0, offset: MTLVertexFormat.float3.stride)
        }
        renderPipelineDescriptor.vertexDescriptor = vertexDescriptor

        mainPassVertexDescriptor = vertexDescriptor
        mainPassRenderPipelineState = try device.makeRenderPipelineState(descriptor: renderPipelineDescriptor)
        
        // MARK: Shadow Render Pass
        
        
        // MARK: Physics Compute Pass
        
        let particleEngine = try MSParticleRenderer(engine: self, library: library)
        particleEngine.setSimulationState(.default)
        particleRenderer = particleEngine
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
        _ = semaphore.wait(timeout: .distantFuture)
        
        // Get the render pass descriptors
        guard let frameRenderPassDescriptor = view.currentRenderPassDescriptor else { return }

        // Create a new buffer to submit to the GPU
        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: frameRenderPassDescriptor) else { return }
        
        // Update the positions of the particles
        
        renderEncoder.setRenderPipelineState(mainPassRenderPipelineState)
        renderEncoder.setDepthStencilState(mainPassDepthStencilState)

        // Tell the scene that rendering is about to begin
        let dt = 1 / Double(view.preferredFramesPerSecond)
        scene.willRender(dt)
        
        // Perform scene rendering here
        
        // Update particle positions (simulate physical interactions)
        //
        // 1. Get the current buffer where particle data is stored
        // 2.
        
        // Render geometry, normal maps, etc. in the first render pass
        
        
//        scene.render(with: renderEncoder)
        
        // 

//        renderEncoder.setVertexBuffer(<#T##buffer: MTLBuffer?##MTLBuffer?#>, offset: <#T##Int#>, index: <#T##Int#>)
        renderEncoder.endEncoding()
        
        // Add a scheduler to signal to the render thread execution can continue
        // The closure is explicit about its capture semantics: here, we are
        // capturing the semaphore by reference
        let semaphoreReference = semaphore
        commandBuffer.addCompletedHandler { [semaphoreReference] _ in
            semaphoreReference.signal()
        }
     
        // Commit the buffer and have it present ASAP
        commandBuffer.present(view.currentDrawable!)
        commandBuffer.commit()
    }
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        // Push the update to the scene so it can reconfigure itself
        scene?.viewDidResize(view as! MTKSceneView, oldSize: viewSize)
    }
    
    // MARK: - Rendering Cases -
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
