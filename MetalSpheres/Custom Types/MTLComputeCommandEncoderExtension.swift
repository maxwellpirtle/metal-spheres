//
//  Created by Maxwell Pirtle on 2/21/21
//  Copyright © 2021 Maxwell Pirtle. All rights reserved.
//
//  Abstract:
//
    

import Metal.MTLComputePass

extension MTLComputePipelineState {
    
    /// Returns the maximum total threadgroup memory that can be allocated
    /// in this compute kernel executing on this device
    var maximumThreadgroupMemoryAllocation: Int {
        // Values can be found via the Metal Feature Set released by Apple
        // at the following link: https://developer.apple.com/metal/Metal-Feature-Set-Tables.pdf
        if device.supportsFamily(.apple1) || device.supportsFamily(.apple2) { return 16_352 }
        else if device.supportsFamily(.apple3)                              { return 16_384 }
        else                                                                { return 32_768 }
    }
    
    /// Computes the largest number of threads in a threadgroup under the
    /// threadgroup memory allocation limit if each thread is to have the given
    /// amount of dedicated threadgroup memory
    func maxTotalThreadsPerThreadgroup(threadgroupMemoryPerThread tmpt: Int, compileTimeThreadgroupMemoryInUse cttm: Int = 0) -> Int {
        /* Integer division `floor` function effect intended */
        min(maxTotalThreadsPerThreadgroup, (maximumThreadgroupMemoryAllocation - cttm) / tmpt)
    }
}
