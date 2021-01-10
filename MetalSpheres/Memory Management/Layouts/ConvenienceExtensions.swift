//
//  Created by Maxwell Pirtle on 8/31/20
//  Copyright © 2020 Maxwell Pirtle. All rights reserved.
//
//  Abstract:
//
    

import MetalKit
import ModelIO.MDLVertexDescriptor

extension MTLVertexFormat {
    /// The stride of each format
    var stride: Int {
        switch self {
        case .float3:   return MemoryLayout<simd_float3>.stride
        case .float4:   return MemoryLayout<simd_float4>.stride
        case .half3:    return 8
        default:        fatalError("Case unaccounted for: \(self)")
        }
    }
}

extension MTLVertexDescriptor {
    convenience init(@ConvenienceList<MTLVertexAttributeDescriptor> descriptors: () -> [MTLVertexAttributeDescriptor]) {
        self.init()
        
        // Assign attributes
        descriptors().forEach { descriptor in
            attributes[descriptor.attributeIndex].format        = descriptor.format
            attributes[descriptor.attributeIndex].bufferIndex   = descriptor.bufferIndex
            attributes[descriptor.attributeIndex].offset        = descriptor.offset
            layouts[descriptor.bufferIndex].stride += descriptor.format.stride
        }
    }
}

extension MDLVertexDescriptor {
    /// Creates a descriptor from the given `MTLVertexDescriptor` and a description of how the file data should be mapped to the attributes of the `MTLVertexDescriptor`
    static func descriptor(basedOn mtlvd: MTLVertexDescriptor, @ConvenienceList<MDLVertexAttributeDescriptor> descriptors: () -> [MDLVertexAttributeDescriptor]) -> MDLVertexDescriptor {
        let vertexDescriptor = MTKModelIOVertexDescriptorFromMetal(mtlvd)
        
        descriptors().forEach { descriptor in
            let attribute = vertexDescriptor.attributes[descriptor.attribute] as! MDLVertexAttribute
            attribute.name = descriptor.name
        }
        
        return vertexDescriptor
    }
}
