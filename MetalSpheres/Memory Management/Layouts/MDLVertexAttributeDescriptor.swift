//
//  Created by Maxwell Pirtle on 9/4/20
//  Copyright © 2020 Maxwell Pirtle. All rights reserved.
//
//  Abstract:
//  An object that describes how ModelIO reads files from the main bundle
    

import Foundation

struct MDLVertexAttributeDescriptor {
    /// The data that is stored in this MDLAttribute (so that the `MTLVertexDescriptor` description matches the `MDLVertexDescriptor` so that the buffers are formatted properly)
    let name: String
    
    /// The attribute number. This refers to the index in the
    /// MSL `[[attribute(n)]]` attribute in the shader file
    let attribute: Int
}
