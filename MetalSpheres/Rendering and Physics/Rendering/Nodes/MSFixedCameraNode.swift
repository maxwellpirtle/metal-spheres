//
//  Created by Maxwell Pirtle on 9/12/20
//  Copyright © 2020 Maxwell Pirtle. All rights reserved.
//
//  Abstract:
//  A special type of camera node that looks towards the center of a ball of a given radius. The position of the camera node represents its position in spherical coordinates
    

import Foundation
import Relativity

class MSFixedCameraNode: MSCameraNode {
    /// The coordinates of the camera relative to the frame of the ball whose center is the focus of the camera
    /// The ball is centered at the origin of the parent node
    var sphericalCoordinates: SphericalCoordinates = .init() {
        didSet {
            position = pointOfInterest + sphericalCoordinates.inCartesianCoordinates()
            eulerAngles.yaw = -sphericalCoordinates.theta
            eulerAngles.pitch = .pi / 2 - sphericalCoordinates.phi
        }
    }

    /// The center of the ball in the frame of the parent node
    var pointOfInterest: simd_float3 { didSet { position = pointOfInterest + sphericalCoordinates.inCartesianCoordinates() } }
    
    // MARK: - Initializers -
    
    /// Create a new camera node focused on the given point
    init(focus: simd_float3 = .zero, aspectRatio ratio: Float, near: Float = 0.1, far: Float = 30, fov: Angle = .π / 2) {
        self.pointOfInterest = focus
        super.init(aspectRatio: ratio, near: near, far: far, fov: fov)
    }
}
