//
//  Created by Maxwell Pirtle on 2/20/21
//  Copyright © 2021 Maxwell Pirtle. All rights reserved.
//
//  Abstract:
    
import Foundation
import Metal

/// An `MSTileBuffer` represents exactly two `MTLBuffer`s. Each buffer
/// acts either to be read from or written to in tile memory. The buffer
/// then switches roles when prompted, having its reading buffer become the writing buffer
class MSTileBuffer<EncodedType> : MSMemory<EncodedType> {
    
    /// The tile memory allocator for this buffer
    private var allocator: MSBufferPairAllocator
    
    /// The buffer that should be read from in this pass
    var referenceBuffer: MTLBuffer { allocator.readBuffer }
    
    /// The buffer that should be written into in this pass
    var refreshedBuffer: MTLBuffer { allocator.writeBuffer }
    
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
    init(device: MTLDevice, options: MTLResourceOptions, length: Int = MemoryLayout<EncodedType>.stride) {
        self.allocator = MSBufferPairAllocator(device: device, resourceOptions: options, length: length, encodedType: EncodedType.self)
        super.init(device: device, options: options, copies: 2, length: length)
    }
    
    // Cycling buffers means changing the read-write assignment
    func exchangeReadWriteAssigment() {
        allocator.exchangeReadWriteAssignment()
    }
    
    /// Encodes the given value into the current dynamic buffer
    override func unsafelyWrite(_ value: inout EncodedType, type: EncodedType.Type = EncodedType.self) {
        // Get the current buffer and bind its memory unsafely
        refreshedBuffer.unsafelyWrite(&value, type: type)
    }
    
    /// Unsafely write array data into the current dynamic buffer
    override func unsafelyWrite<T>(_ value: inout [T], type: T.Type = T.self) {
        // Get the current buffer and bind its memory unsafely
        refreshedBuffer.unsafelyWrite(&value, type: type)
        referenceBuffer.unsafelyWrite(&value, type: type)
    }
    
    /// Returns the value held in the current dynamic buffer
    override func unsafelyRead<T>(capacity: Int, reading block: (UnsafePointer<T>) -> Void) {
        refreshedBuffer.unsafelyRead(capacity: capacity, reading: block)
    }
    
    /// Calls `didModifyRange(_:)` on the underlying buffer we are writing to.
    /// Use this if the underlying dynamic buffer was written to
    /// and the storage mode of the buffer was `.storageModeManaged`
    override func didModifyRange(_ range: Range<Int>) {
        refreshedBuffer.didModifyRange(range)
        referenceBuffer.didModifyRange(range)
    }
}
