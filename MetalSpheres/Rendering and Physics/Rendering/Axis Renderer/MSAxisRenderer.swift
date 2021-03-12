//
//  Created by Maxwell Pirtle on 3/11/21
//  Copyright © 2021 Maxwell Pirtle. All rights reserved.
//
//  Abstract:
//
    

import Metal

/// An `MSAxisRenderer` represents a type of object that renders a single reference frame into the
/// scene to make it easier to see the spatial relations between points for debugging and general-use purposes
final class MSAxisRenderer: NSObject, MSRenderer {

    /// The pipeline state of the axis render pass
    private var renderPipelineState: MTLRenderPipelineState!
    
    init(renderDevice device: MTLDevice, view: MSSceneView, library: MTLLibrary) throws {
        guard let vertexAxis = library.makeFunction(name: "axis_vertex"),
              let fragmentAxis = library.makeFunction(name: "axis_fragment")
        else { fatalError("Expected every function in source project") }
        
        // MARK: Main Render Pass
        
        let renderPipelineDescriptor = MTLRenderPipelineDescriptor()
        renderPipelineDescriptor.label = "Axis pipeline"
        renderPipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        renderPipelineDescriptor.depthAttachmentPixelFormat = .depth32Float
        renderPipelineDescriptor.vertexFunction = vertexAxis
        renderPipelineDescriptor.fragmentFunction = fragmentAxis
        
        // Attempts to create the render pipeline state object from the given shader cache library
        self.renderPipelineState = try device.makeRenderPipelineState(descriptor: renderPipelineDescriptor)
    }
    
    func encodeRenderCommands(into renderEncoder: MTLRenderCommandEncoder, commandBuffer: MTLCommandBuffer, uniforms: MSBuffer<MSUniforms>) {
        renderEncoder.setRenderPipelineState(renderPipelineState)
        
        let vertexBytes = [MSConstants.xyplane, MSConstants.xzplane, MSConstants.yzplane]
        for var axisColorIndex: ushort in 0..<3 {
            
            // Get a copy of the data we will again copy
            var bytes = vertexBytes[Int(axisColorIndex)]
            
            renderEncoder.setVertexBytes(&bytes, length: bytes.count * MemoryLayout<simd_float3>.stride, index: 0)
            renderEncoder.setVertexBuffer(uniforms.dynamicBuffer, offset: uniforms.offset, index: 1)
            renderEncoder.setFragmentBytes(&axisColorIndex, length: MemoryLayout<ushort>.stride, index: 1)
            renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 12)
        }
    }
}
