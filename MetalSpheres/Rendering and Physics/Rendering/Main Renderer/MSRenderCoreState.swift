//
//  Created by Maxwell Pirtle on 12/24/20
//  Copyright © 2020 Maxwell Pirtle. All rights reserved.
//
//  Abstract:
//
    

import Foundation

struct MSRenderCoreState {
    
    static let `default`: MSRenderCoreState = .init()
    
    /// Whether or not the coordinate axis should be drawn
    var drawsCoordinateSystem = false
    
    /// Whether or not the next frame should be captured in Xcode for debugging purposes
    var captureCommandsInXcodeNextFrame = false
}
