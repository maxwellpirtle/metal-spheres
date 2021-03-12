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
    
    /// The number of instances of data fit within each buffer in the store
    private(set) var instanceCount: Int = 1
    
    /// The size of a single buffer in the ring. Each buffer is created such that
    /// they have the same size as the other buffers
    var lengthOfBuffersManaged: Int { buffers.first?.length ?? 0 }
    
    /// The total allocation length of all buffers in the set of buffers
    var totalMemoryAllocated: Int { buffers.reduce(0) { $0 + $1.length } }
    
    /// The set of buffers in the buffer ring
    private var buffers: [MTLBuffer] = []
    
    // MARK: - Current Buffers -
    
    /// Whether or not the buffers share memory in a single MTLBuffer (offset at different points in the buffer
    private(set) var contiguouslyStoresBuffers: Bool = false
    
    /// Returns the current buffer in use
    var currentBuffer: MTLBuffer { self[index: currentIndex] }
    
    /// The current offset in the offset ring
    private(set) var currentOffset: Int = 0
    
    /// The current index in the buffer ring
    private var currentIndex: Int = 0

    /// Returns a buffer at the given subscript
    private subscript(index i: Int) -> MTLBuffer { buffers[i] }
    
    // MARK: - Initializer -
    
    /// Create an allocator to handle the buffers provided
    private init(@FallibleArrayAllocator<MTLBuffer> allocation: () -> [MTLBuffer]) { self.buffers = allocation() }
    
    // MARK: - API -
    
    /// Updates the current buffer that is being written into
    func cycleToNextBuffer() {
        
        // Move to the next buffer in the ring in the MTLBuffer
        // shared between the three
        if contiguouslyStoresBuffers {
            currentOffset += currentBuffer.length / instanceCount
            currentOffset %= totalMemoryAllocated
        }
        
        // Move to the next buffer in the ring
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
    convenience init<T>(device: MTLDevice, buffersInFlight: Int, resourceOptions: MTLResourceOptions, addressSpace: MTLAddressSpace, length: Int = MemoryLayout<T>.stride, encodedType: T.Type = T.self, shareMemory: Bool = false)
    {
        let bufferLength = shareMemory ? buffersInFlight * length : length
        let buffersToCreate = shareMemory ? 1 : buffersInFlight
        
        // Note that this call makes use of the `@_functionBuilder` attribute so that
        // the first closure is actually binded as a parameter into the `FallibleArrayAllocator`
        // initializer
        self.init {
            { (i: Int) in device.makeBuffer(length: bufferLength, options: resourceOptions, alingedTo: addressSpace) }
            (0..<buffersToCreate).map { $0 }
        }
        
        self.contiguouslyStoresBuffers = shareMemory
        self.instanceCount = shareMemory ? buffersInFlight : 1
    }
}
