//
//  Created by Maxwell Pirtle on 8/23/20
//  Copyright © 2020 Maxwell Pirtle. All rights reserved.
//
//  Abstract:
//  Holds a set of `MTLBuffer` objects and properly returns the correct one
//  when queried
    

import Foundation
import Metal.MTLBuffer

class MSBufferRingAllocator {
    
    // MARK: - Buffer Data -
    
    /// The number of buffers in the store
    var bufferCount: Int { buffers.count }
    
    /// The set of buffers
    private var buffers: [MTLBuffer] = []
    
    // MARK: - Current Buffers -
    
    /// Returns the current buffer in use
    var currentBuffer: MTLBuffer { self[index: currentIndex] }
    
    /// The current index in the store
    private var currentIndex: Int = 0
    
    /// Returns a buffer at the given subscript
    private subscript(index i: Int) -> MTLBuffer { buffers[i] }
    
    // MARK: - Initializer -
    
    /// Create an allocator to handle the buffers provided
    private init(@FallibleArrayAllocator<MTLBuffer> allocation: () -> [MTLBuffer]) { self.buffers = allocation() }
    
    // MARK: - API -
    
    /// Updates the current buffer that is being written into
    func cycleToNextBuffer() {
        currentIndex += 1
        currentIndex %= bufferCount
    }
    
    /// Assigns a label to each buffer in the list
    /// starting with the given prefix. Included in the buffer
    /// is a unique signature identifying the buffer in the allocator
    /// for debug purposes (so that it's clear which one of the buffers
    /// is in use in instruments for example)
    func assignBufferDebugLabels(withPrefix prefix: String?) {
        buffers.enumerated().forEach { wrapped in
            // Unique for each particular instance
            let customString = ". Buffer index \(wrapped.offset) in MSMemoryAllocator"
            wrapped.element.label = prefix?.appending(customString)
        }
    }
}

extension MSBufferRingAllocator {
    /// A convenience initializer that allocates `MTLBuffer` objects
    /// with the provided device for the given MSBuffer instance. The length of the buffer can vary as well,
    /// but is defaulted to the stride of the type provided
    convenience init<T>(device: MTLDevice, buffersInFlight: Int, resourceOptions: MTLResourceOptions, length: Int = MemoryLayout<T>.stride, encodedType: T.Type = T.self) {
        // Note that this call makes use of the `@_functionBuilder` attribute so that
        // the first closure is actually binded as a parameter into the `FallibleArrayAllocator`
        // initializer
        self.init {
            { (i: Int) in device.makeBuffer(length: length, options: resourceOptions) }
            (0..<buffersInFlight).map { $0 }
        }
    }
}
