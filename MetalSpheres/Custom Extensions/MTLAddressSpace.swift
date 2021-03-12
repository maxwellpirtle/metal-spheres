//
//  Created by Maxwell Pirtle on 3/11/21
//  Copyright © 2021 Maxwell Pirtle. All rights reserved.
//
//  Abstract:
//
    

import Foundation


/// Represents one of the (currently) 6 memory address spaces in the
/// Metal Shading Language
struct MTLAddressSpace: OptionSet {
    var rawValue: Int
    typealias RawValue = Int
    init(rawValue: Int) { self.rawValue = rawValue }
    
    /// The device address space
    static let device: MTLAddressSpace = .init(rawValue: 1 << 0)
    
    /// The constant address space
    static let constant: MTLAddressSpace = .init(rawValue: 1 << 1)
    
    /// The thread address space
    static let thread: MTLAddressSpace = .init(rawValue: 1 << 2)
    
    /// The threadgroup address space
    static let threadgroup: MTLAddressSpace = .init(rawValue: 1 << 3)
    
    /// The threadgroup_imageblock address space
    static let threadgroupImageblock: MTLAddressSpace = .init(rawValue: 1 << 4)
    
    /// The ray_data address space
    static let rayData: MTLAddressSpace = .init(rawValue: 1 << 5)
}
