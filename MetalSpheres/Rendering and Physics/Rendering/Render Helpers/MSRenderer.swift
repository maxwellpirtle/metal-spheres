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

    /// Queries the rendering instance to encode its rendering commands into the
    /// given render command encoder derived from the given command buffer.
    /// A buffer of scene uniforms is passed in case rendering makes use of the camera or
    /// other scene uniform properties
    func encodeRenderCommands(into renderEncoder: MTLRenderCommandEncoder, commandBuffer: MTLCommandBuffer, uniforms: MSBuffer<MSUniforms>)
}
