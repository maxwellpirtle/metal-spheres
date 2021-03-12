//
//  Created by Maxwell Pirtle on 2/28/21
//  Copyright © 2021 Maxwell Pirtle. All rights reserved.
//
//  Abstract:
//

import Foundation

// Make simd vector types iterable
extension SIMD3 : Sequence {
    public typealias Element = Scalar
    public typealias Iterator = SIMD3Iterator<Scalar>
    public func makeIterator() -> SIMD3Iterator<Scalar> { SIMD3Iterator<Scalar>(vector: self) }
}

/// A `SIMD3Iterator` is a custom iterator that walks through the components
/// of a 3D simd vector
public struct SIMD3Iterator<Scalar>: IteratorProtocol where Scalar: SIMDScalar {
    
    public typealias Element = Scalar
    
    // The current index in the simd vector
    private var componentIndex = 0
    
    // The vector we are iterating over
    private var vector: SIMD3<Scalar>
    
    init(vector: SIMD3<Scalar>) {
        self.vector = vector
    }
    
    public mutating func next() -> Scalar? {
        // Move to the next index
        defer { componentIndex += 1 }
        
        switch componentIndex {
        case 0: return vector.x
        case 1: return vector.y
        case 2: return vector.z
        default: return nil
        }
    }
}
