//
//  Created by Maxwell Pirtle on 12/2/20
//  Copyright © 2020 Maxwell Pirtle. All rights reserved.
//
//  Abstract:
//
    

import Metal.MTLBuffer

extension MTLBuffer {
    
    /// Unsafely write data into the buffer.
    /// 1. If the buffer has storage mode `.storageModePrivate`
    ///     the write will raise an exception.
    ///
    /// 2. If the buffer has storage mode `.storageModeManaged` or `.storageModeShared`,
    ///    you must ensure that the GPU is not accessing the resource
    ///    when you write to it
    func unsafelyWrite<T>(_ value: inout T, offset: Int = 0, type: T.Type = T.self) {
        precondition(storageMode != .private, "Attempting to write into private GPU buffer from the CPU. This is invalid")
        
        (contents() + offset)
            .bindMemory(to: type, capacity: 1)
            .assign(from: &value, count: 1)
    }
    
    /// Unsafely write data into the buffer.
    /// 1. If the buffer has storage mode `.storageModePrivate`
    ///     the write will raise an exception.
    ///
    /// 2. If the buffer has storage mode `.storageModeManaged` or `.storageModeShared`,
    ///    you must ensure that the GPU is not accessing the resource
    ///    when you write to it
    func unsafelyWrite<T>(_ value: inout [T], offset: Int = 0, type: T.Type = T.self) {
        precondition(storageMode != .private, "Attempting to write into private GPU buffer from the CPU. This is invalid")
        
        (contents() + offset)
            .bindMemory(to: type, capacity: value.count)
            .assign(from: &value, count: value.count)
    }
    
    /// Unsafely read data held in the buffer.
    /// 1. If the buffer has storage mode `.storageModePrivate`
    ///     the read will raise an exception.
    ///
    /// 2. If the buffer has storage mode `.storageModeManaged` or `.storageModeShared`,
    ///    you must ensure that the GPU is not accessing the resource
    ///    when you read from it
    func unsafelyRead<T>(capacity: Int, offset: Int = 0, reading: (UnsafePointer<T>) -> Void) {
        precondition(storageMode != .private, "Attempting to read from private GPU buffer from the CPU. This is invalid")
        
        reading((contents() + offset).bindMemory(to: T.self, capacity: capacity))
    }
}
