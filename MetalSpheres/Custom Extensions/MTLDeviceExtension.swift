//
//  Created by Maxwell Pirtle on 3/11/21
//  Copyright © 2021 Maxwell Pirtle. All rights reserved.
//
//  Abstract:
//
    

import Metal

extension MTLDevice {
    
    /// Creates a new buffer that can store the given length
    /// of material whose alignment matches that of the given address space
    func makeBuffer(length: Int, options resourceOptions: MTLResourceOptions, alingedTo addressSpace: MTLAddressSpace) -> MTLBuffer? {
        #if os(macOS)
        let length: Int = {
            switch addressSpace {
            case .device:   return length
            case .constant: return 256.smallestMultiple(greaterThanOrEqualTo: length)
            default:        fatalError("Unsupported allocation for MTLBuffer. A MTLBuffer can only bind to the device and constant address spaces in a shader")
            }
        }()
        return makeBuffer(length: length, options: resourceOptions)
        #elseif os(iOS) || os(tvOS)
        let length: Int = {
            switch addressSpace {
            case .device:   return length
            case .constant: return max(4, length)
            default:        fatalError("Unsupported allocation for MTLBuffer. A MTLBuffer can only bind to the device and constant address spaces in a shader")
            }
        }()
        return makeBuffer(length: length, options: resourceOptions)
        #endif
    }
}
