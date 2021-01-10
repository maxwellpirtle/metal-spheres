//
//  Created by Maxwell Pirtle on 8/31/20
//  Copyright © 2020 Maxwell Pirtle. All rights reserved.
//
//  Abstract:
//
    

import Metal.MTLVertexDescriptor

struct MTLVertexAttributeDescriptor {
    /// The attribute index that is descibed.
    /// This refers to the index in the MSL `[[attribute(n)]]`
    /// attribute in the shader file
    let attributeIndex: Int
    
    /// The data type of this index
    let format: MTLVertexFormat
    
    /// The buffer within which the data for the attribute is obtained
    let bufferIndex: Int
    
    /// The offset from the start of the pointer to a given vertex's data that holds this particular attribute
    let offset: Int
}
