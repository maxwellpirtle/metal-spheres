//
//  Created by Maxwell Pirtle on 2/20/21
//  Copyright © 2021 Maxwell Pirtle. All rights reserved.
//
//  Abstract:
//
    

import Foundation
import Metal.MTLBuffer

/// A reference to a value encoded within a fixed layout `UnsafeMutableRawPointer (void*)`
/// that is written to by the CPU. Only use an `MSBuffer<EncodedType>` when the storage mode of the
/// resource type is `.storageModeShared` or `.storageModeManaged`, where the CPU might write into the
/// buffer while a GPU is reading from it
class MSBuffer<EncodedType> : MSMemory<EncodedType> {
    
    // MARK: - Properties -
    
    override var label: String? { didSet { allocator.assignBufferDebugLabels(withPrefix: label) } }
    
    /// A reference to the allocator that manages
    private var allocator: MSBufferRingAllocator
    
    /// The buffer that is currently not being read by the GPU holding the
    /// value encoded by this buffer
    var dynamicBuffer: MTLBuffer! { allocator.currentBuffer }
    
    /// The offset from the start of the buffer within the current dynamic buffer that
    /// the data encoded in this buffer is located
    var offset: Int { allocator.currentOffset }
    
    // MARK: - Initializers -

    init(device: MTLDevice, options: MTLResourceOptions, addressSpace: MTLAddressSpace, copies: Int, length: Int = MemoryLayout<EncodedType>.stride, shareMemory: Bool = false) {
        guard !options.contains([.storageModePrivate]) else { fatalError("Cannot initialize an MSBuffer whose underlying memory can only be accessed by the GPU") }
        
        self.allocator = MSBufferRingAllocator(device: device, buffersInFlight: copies, resourceOptions: options, addressSpace: addressSpace, length: length, encodedType: EncodedType.self, shareMemory: shareMemory)
        super.init(device: device, options: options, copies: copies, length: length)
    }
    
    // MARK: - API -
    
    /// Changes the underlying `MTLBuffer` now referenced by this buffer object
    func cycleToNextAvailableBuffer() { allocator.cycleToNextBuffer() }
    
    /// Encodes the given value into the current dynamic buffer
    override func unsafelyWrite(_ value: inout EncodedType, type: EncodedType.Type = EncodedType.self) {
        // Get the current buffer and bind its memory unsafely
        dynamicBuffer.unsafelyWrite(&value, type: type)
    }
    
    /// Unsafely write array data into the current dynamic buffer
    override func unsafelyWrite<T>(_ value: inout [T], type: T.Type = T.self) {
        // Get the current buffer and bind its memory unsafely
        dynamicBuffer.unsafelyWrite(&value, type: type)
    }
    
    /// Returns the value held in the current dynamic buffer
    override func unsafelyRead<T>(capacity: Int, reading block: (UnsafePointer<T>) -> Void) {
        dynamicBuffer.unsafelyRead(capacity: capacity, reading: block)
    }
    
    #if os(macOS)
    /// Calls `didModifyRange(_:)` on the underlying dynamic buffer.
    /// Use this if the underlying dynamic buffer was written to
    /// and the storage mode of the buffer was `.storageModeManaged`
    override func didModifyRange(_ range: Range<Int>) {
        dynamicBuffer.didModifyRange(range)
    }
    #endif
}

