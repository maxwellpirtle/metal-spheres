//
//  Created by Maxwell Pirtle on 2/13/21
//  Copyright © 2021 Maxwell Pirtle. All rights reserved.
//
//  Abstract:
//
    

import Metal.MTLBuffer

extension MTLSize {
    
    /// The number of threads described by this size struct.
    /// The interpretation is only meaningful if this instance
    /// represents threads in a dispatch
    var totalThreads: Int { height * width * depth }
}
