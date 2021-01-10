//
//  Created by Maxwell Pirtle on 8/23/20
//  Copyright © 2020 Maxwell Pirtle. All rights reserved.
//
//  Abstract:
//  Holds a set of `MTLBuffer` objects and properly returns the correct one
//  when queried
    

import Foundation
import Metal.MTLBuffer

final class MSMemoryAllocator {
    
    // MARK: - Buffer Data -
    
    /// The number of buffers in the store
    var bufferCount: Int { buffers.count }
    
    /// The set of buffers
    private var buffers: [MTLBuffer] = []
    
    // MARK: - Current Buffers -
    
    /// Returns the current buffer in use
    fileprivate var currentBuffer: MTLBuffer { self[index: currentIndex] }
    
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
}

extension MSMemoryAllocator {
    /// A convenience initializer that allocates `MTLBuffer` objects
    /// with the provided device for the given MSBuffer instance
    convenience init<T>(device: MTLDevice, buffersInFlight: Int, resourceOptions: MTLResourceOptions, encodedType: T.Type = T.self) {
        // Note that this call makes use of the `@_functionBuilder` attribute so that
        // the first closure is actually binded as a parameter into the `FallibleArrayAllocator`
        // initializer
        self.init {
            { (i: Int) in device.makeBuffer(length: MemoryLayout<T>.stride, options: resourceOptions) }
            (0..<buffersInFlight).map { $0 }
        }
    }
}


/// A reference to a value encoded within a fixed layout `UnsafeMutableRawPointer (void*)`
/// that is written to by the CPU. Only use an `MSBuffer<EncodedType>` when the storage mode of the
/// resource type is `.storageModeShared` or `.storageModeManaged`, where the CPU might write into the
/// buffer while a GPU is reading from it
final class MSBuffer<EncodedType> {
    
    // MARK: - Properties -
    
    /// A reference to the allocator that manages
    private(set) var allocator: MSMemoryAllocator
    
    /// The length of the buffer referenced by this object
    let length: Int
    
    /// The options associated with this buffer
    let options: MTLResourceOptions
    
    /// The length of a single unit in the buffer
    var stride: Int { MemoryLayout<EncodedType>.stride }
    
    /// The buffer that is currently not being read by the GPU holding the
    /// value encoded by this buffer
    var dynamicBuffer: MTLBuffer! { allocator.currentBuffer }
    
    // MARK: - Initializers -
    
    // No public initializers
    
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
    init(device: MTLDevice, options: MTLResourceOptions, copies: Int) {
        // Memoryless mode is only available on macOS 11.0 and up
        if #available(OSX 11.0, *) {
            precondition(!options.contains([.storageModeMemoryless, .storageModePrivate]), "Only `.storageModeShared` and `.storageModeManaged` allowed")
        } else {
            precondition(!options.contains(.storageModePrivate), "Only `.storageModeShared` and `.storageModeManaged` allowed")
        }
        
        self.length = MemoryLayout<EncodedType>.stride
        self.options = options
        self.allocator = MSMemoryAllocator(device: device, buffersInFlight: copies, resourceOptions: options, encodedType: EncodedType.self)
    }
    
    // MARK: - API -
    
    /// Encodes the given value into the buffers
    func unsafelyWrite(_ value: inout EncodedType) {
        // Get the current buffer and bind its memory unsafely
        dynamicBuffer.unsafelyWrite(&value, capacity: 1)
    }
    
    /// Returns the value held in the buffer currently
    func unsafelyRead(capacity: Int, reading block: (UnsafePointer<EncodedType>) -> Void) {
        dynamicBuffer.unsafelyRead(capacity: capacity, reading: block)
    }
}

