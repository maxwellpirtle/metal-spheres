//
//  Created by Maxwell Pirtle on 2/20/21
//  Copyright © 2021 Maxwell Pirtle. All rights reserved.
//
//  Abstract:
//
    

import Foundation
import Metal

/// An `MSMemory` represents a particular allocation made by Metal
/// from a set of Metal buffer allocations of the same length. The memory should reside in system
/// memory as either a shared or manged buffer
class MSMemory<EncodedType> {
    
    /// A debug label representing this allocation pool
    var label: String?
    
    /// The length of the buffers referenced by this object
    let length: Int
    
    /// The options associated with this buffer
    let options: MTLResourceOptions
    
    /// The length of a single unit in the buffer
    var stride: Int { MemoryLayout<EncodedType>.stride }
    
    /**
     Initializes the descriptor with the value to encode into an `MTLBuffer`, the number of values (if the value is an array type),
     and the resource options for the buffer, either of mode `.storageModeShared` or `.storageModeManaged`. If any other mode is
     specified, an exception is raised
     - Parameters:
     - device:
     - options:
     - copies:
     - Precondition:
     Checks whether or not the buffer has an appropriate storage mode
     */
    init(device: MTLDevice, options: MTLResourceOptions, copies: Int, length: Int = MemoryLayout<EncodedType>.stride) {
        // Memoryless mode is only available on macOS 11.0 and up
        if #available(OSX 11.0, *) {
            precondition(!options.contains([.storageModeMemoryless, .storageModePrivate]), "Only `.storageModeShared` and `.storageModeManaged` allowed")
        } else {
            precondition(!options.contains(.storageModePrivate), "Only `.storageModeShared` and `.storageModeManaged` allowed")
        }
        
        self.length = MemoryLayout<EncodedType>.stride
        self.options = options
    }
    
    // Each subclass defines what it means to read and write from it at any given point
    func unsafelyWrite(_ value: inout EncodedType, capacity: Int = 1, type: EncodedType.Type = EncodedType.self) {}
    func unsafelyWrite<T>(_ value: inout [T], type: T.Type = T.self) {}
    func unsafelyRead<T>(capacity: Int, reading block: (UnsafePointer<T>) -> Void) {}
    func didModifyRange(_ range: Range<Int>) {}
}
