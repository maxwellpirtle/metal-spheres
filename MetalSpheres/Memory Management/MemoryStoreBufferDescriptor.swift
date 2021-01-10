//
//  Created by Maxwell Pirtle on 8/25/20
//  Copyright © 2020 Maxwell Pirtle. All rights reserved.
//
//  Abstract:
//  Describes how an object
    

import Foundation
import Metal.MTLResource

typealias MemoryStoreBufferDescriptorArray = [MSMemoryStoreBufferDescriptor]

/// A reference type is used to hold onto values
class MSMemoryStoreBufferDescriptor {
    /// The length of the buffer
    let length: Int
    
    /// The value that is encoded
    var value: Any
    
    /// The options associated with this buffer
    let options: MTLResourceOptions
    
    /// The number of duplications of this resource that should be created
    let resourceCount: UInt
    
    /**
        Initializes the descriptor with the value to encode into an `MTLBuffer`, the number of values (if the value is an array type),
        and the resource options for the buffer
    */
    init<T>(value: T, count: Int? = nil, options: MTLResourceOptions, duplicating times: UInt = 1) {
        self.length = MemoryLayout<T>.stride
        self.value = value
        self.resourceCount = times
        self.options = options
    }
}

extension MSMemoryStoreBufferDescriptor {
    /**
        Initializes the descriptor with the value to encode into an `MTLBuffer`, the number of values (if the value is an array type),
        and the resource options for the buffer
    */
    convenience init<T>(value: UnsafePointer<T>, count: Int? = nil, options: MTLResourceOptions, duplicating times: UInt = 1) { self.init(value: value.pointee, count: count, options: options, duplicating: times) }
}
