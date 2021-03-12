//
//  Created by Maxwell Pirtle on 9/4/20
//  Copyright © 2020 Maxwell Pirtle. All rights reserved.
//
//  Abstract:
//
    

import AppKit.NSView
import simd.matrix
import GameplayKit.GKRandomDistribution

extension String {
    var pathSplit: (name: String, extension: String) {
        let split = self.split(separator: ".").map { String($0) }
        return (split[0], split[1])
    }
}

extension Int {
    init(CBooleanConvert bool: Bool) { self = bool ? 1 : 0 }
    
    /// Returns the largest multiple of this number that is greater than or equal to the given number
    func smallestMultiple(greaterThanOrEqualTo value: Int) -> Int {
        value % self == 0 ? value : self * (value / self + 1)
    }
}

extension UInt {
    /// Returns the largest multiple of this number that is greater than or equal to the given number
    func smallestMultiple(greaterThanOrEqualTo value: UInt) -> UInt {
        value % self == 0 ? value : self * (value / self + 1)
    }
}


extension Array where Element : AnyObject {
    // Moves the element from the second arry into this one
    mutating func removeReference(_ element: Element) { removeAll { $0 === element } }
}

extension Bool {
    mutating func negate() { self = !self }
}

extension Comparable {
    func clamped(to limits: ClosedRange<Self>) -> Self { min(max(self, limits.lowerBound), limits.upperBound) }
}

extension ClosedRange where Bound == Float {
    
    /// Computes a random value from this range by querying a uniform value from
    /// the given random source. We map the random source's `nextUniform()` range from [0.0, 1.0]
    /// to this range's [lowerBound, upperBound]
    func randomValue(withRandomGenerator random: GKRandom) -> Float {
        let interpolate = random.nextUniform()
        return lowerBound * (1.0 - interpolate) + interpolate * upperBound
    }
}

extension NSView { var aspectRatio: CGFloat { frame.size.height / frame.size.width } }

extension GKRandomDistribution {
    /// A distribution that always returns the given value
    static func uniformDistribution(withValue value: Int) -> GKFixedDistribution { GKFixedDistribution(uniformValue: value) }
    
    /// A distribution that always returns the value 0
    static var zeroDistribution: GKFixedDistribution { .uniformDistribution(withValue: 0) }
    
    /// Returns a floating point range with values ranging from the lowest value to the highest value
    var distributionRange: ClosedRange<Float> { Float(lowestValue)...Float(highestValue) }
    
    /// Returns a new random floating point value within the distribution range
    func nextFloatInDistributionRange() -> Float { distributionRange.randomValue(withRandomGenerator: self) }
}

