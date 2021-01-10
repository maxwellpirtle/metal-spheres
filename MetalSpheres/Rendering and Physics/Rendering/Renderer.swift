//
//  Created by Maxwell Pirtle on 8/23/20
//  Copyright © 2020 Maxwell Pirtle. All rights reserved.
//
//  Abstract:
//
    

import Foundation
import MetalKit
import Relativity

class MSRenderer: NSObject, MTKViewDelegate {
    
    // MARK: Properties
    
    /// The device object that generates buffers, textures, etc
    private(set) var primaryDevice: MTLDevice
    
    /// The other devices (if any) that can be used for scheduling work
    private var additionalDevices: RendererDeviceExtension?
    
    /// The command queue for committing work to the GPU
    private var commandQueue: MTLCommandQueue!
    
    /// A triple-buffer system. Instances write to three different buffers to prevent processor stalls. Each `MemoryStore` instance holds reference to the buffers for each render pass
    private var memoryStores: [MemoryStore] = []
    
    /// The scene that is rendered
    private var scene: MTLScene?
    
    // MARK: Initializer
    init(view: MTKView) {
        
        // Assert that the view has a valid device
        guard let device = view.device else { preconditionFailure("View \(view) does not have an associated device object") }
        
        primaryDevice = device
        viewSize = view.frame.size
        
        super.init()
        
        // Set the delegate of the view to the renderer
        view.delegate = self
        
        // Create the command queue
        commandQueue = device.makeCommandQueue()
    }
    
    // MARK: Main Render Code
    
    /// The size of the view that the renderer draws into
    private(set) var viewSize: CGSize
    
    func draw(in view: MTKView) {
        guard let drawable = view.currentDrawable, let renderPassDescriptor = view.currentRenderPassDescriptor else { return }

        // Create a new buffer to submit to the GPU
        guard let commandBuffer = commandQueue.makeCommandBuffer(), let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else { return }
        
        renderEncoder.endEncoding()
        
        // Commit the buffer and have it present ASAP
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) { viewSize = size }
}

