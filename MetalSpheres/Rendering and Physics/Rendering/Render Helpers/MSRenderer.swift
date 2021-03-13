//
//  Created by Maxwell Pirtle on 3/11/21
//  Copyright © 2021 Maxwell Pirtle. All rights reserved.
//
//  Abstract:
//
    

import Foundation
import Metal.MTLCommandBuffer


/// An `MSRenderer` type is one that handles encoding render commands on its own
protocol MSRenderer: AnyObject {
    
    /// Sends a message to the rendering object that a new render encoding is about to commence
    /// in the central pipeline state this renderer is connected to
    func renderingWillBegin(with commandBuffer: MTLCommandBuffer, phase: MSRendererCore.RenderingPhase, uniforms: MSBuffer<MSUniforms>)

    /// Queries the rendering instance to encode its rendering commands into the
    /// given render command encoder derived from the given command buffer.
    /// A buffer of scene uniforms is passed in case rendering makes use of the camera or
    /// other scene uniform properties
    func encodeRenderCommands(into renderEncoder: MTLRenderCommandEncoder, commandBuffer: MTLCommandBuffer, uniforms: MSBuffer<MSUniforms>)
}
