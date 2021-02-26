//
//  Created by Maxwell Pirtle on 2/20/21
//  Copyright © 2021 Maxwell Pirtle. All rights reserved.
//
//  Abstract:
//
    

import Foundation
import Metal.MTLBuffer

/// An `MSBufferPairAllocator` is a special kind of memory allocator that
/// in particular allocates buffers in system memory that are meant to be copied into
/// tile memory
class MSBufferPairAllocator {
    
    // MARK: - Buffer Data -
    
    /// The number of buffers in the store. In this case, there are only two we are working with
    var bufferCount: Int { 2 }
    
    // MARK: - Current Buffers -
    
    /// The buffer we are writing into
    private(set) var writeBuffer: MTLBuffer!
    
    /// The buffer that we are reading from
    private(set) var readBuffer: MTLBuffer!
    
    // MARK: - Initializer -
    
    /// Creates a pair of `MTLBuffer`s, each with the given resource options and length, that act as the read and write
    /// buffers copied into and written into from tile memory
    init<T>(device: MTLDevice, resourceOptions: MTLResourceOptions, length: Int = MemoryLayout<T>.stride, encodedType: T.Type = T.self) {
        writeBuffer = device.makeBuffer(length: length, options: resourceOptions)
        readBuffer = device.makeBuffer(length: length, options: resourceOptions)
    }

    // MARK: - API -
    
    /// Updates the current buffer that is being written into
    func exchangeReadWriteAssignment() { swap(&writeBuffer, &readBuffer) }
}
