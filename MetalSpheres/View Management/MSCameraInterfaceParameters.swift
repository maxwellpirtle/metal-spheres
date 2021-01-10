//
//  Created by Maxwell Pirtle on 12/18/20
//  Copyright © 2020 Maxwell Pirtle. All rights reserved.
//
//  Abstract:
//
    

import Foundation

// A value of 1.0 signifies a value relative to the constant specified in
// MSConstants. Each parameter value corresponds to one of these values
struct MSCameraInterfaceParameters {
    var forwardMotionSensitivity    = Float(1.0)
    var rightMotionSensitivity      = Float(1.0)
    var upMotionSensitivity         = Float(1.0)
    var rollSensitivity             = Float(1.0)
    var pitchSensitivity            = Float(1.0)
    var yawSensitivity              = Float(1.0)
}
