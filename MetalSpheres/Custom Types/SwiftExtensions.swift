//
//  Created by Maxwell Pirtle on 9/4/20
//  Copyright © 2020 Maxwell Pirtle. All rights reserved.
//
//  Abstract:
//
    

import AppKit.NSView
import simd.matrix

extension String {
    var pathSplit: (name: String, extension: String) {
        let split = self.split(separator: ".").map { String($0) }
        return (split[0], split[1])
    }
}

extension Int {
    init(CBooleanConvert bool: Bool) { self = bool ? 1 : 0 }
}

extension UInt {
    /// Returns the largest multiple of this number that is greater than or equal to the given number
    func smallestMultiple(greaterThanOrEqualTo value: UInt) -> UInt {
        value % self == 0 ? value : self * (value / self + 1)
    }
}

extension NSView { var aspectRatio: CGFloat { frame.size.height / frame.size.width } }


extension Array where Element : AnyObject {
    // Moves the element from the second arry into this one
    mutating func removeReference(_ element: Element) { removeAll { $0 === element } }
}

extension Bool {
    mutating func negate() { self = !self }
}
