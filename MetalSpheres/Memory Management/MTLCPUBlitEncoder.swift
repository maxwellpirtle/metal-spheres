//
//  Created by Maxwell Pirtle on 3/12/21
//  Copyright © 2021 Maxwell Pirtle. All rights reserved.
//
//  Abstract:
//
    

import Metal


/// A `MTLCPUBlitEncoder` is an object that writes data into `MTLBuffer`s on the CPU
/// efficiently. It takes advantage of the several available cores on a given CPU
/// by using Grand Central Dispatch (GCD) queues to schedule work in parallel
class MTLCPUBlitEncoder: NSObject {
    
    /// How urgent it is that this CPU blit encoder gets its work done
    let qos: QualityOfService
    
    init(qos: QualityOfService) { self.qos = qos }
    
    /// Given a `MTLBuffer` and an array of values to write into the buffer,
    /// writes the set of values into the buffer in parallel on multiple threads
    func synchronousCopy<T>(_ data: inout [T], into destinationBuffer: MTLBuffer, offset: Int) {
        
        
    }
    
    /// Given a `MTLBuffer` and an array of values to write into the buffer,
    /// writes the set of values into the buffer in parallel on multiple threads
    func asynchronousCopy<T>(_ data: inout [T], into destinationBuffer: MTLBuffer, offset: Int, completion: @escaping (MTLBuffer) -> Void) {
        
    }
}
