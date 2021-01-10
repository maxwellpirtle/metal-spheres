//
//  Created by Maxwell Pirtle on 9/3/20
//  Copyright © 2020 Maxwell Pirtle. All rights reserved.
//
//  Abstract:
//  Represents an observer in a scene.
    

import simd
import Relativity

class MSCameraNode: MSNode {
    
    // MARK: - Camera Properties -
    
    /// The field of view of the camera
    var fov: Angle = .π / 2
    
    /// The wedge field of view of the camera
    private(set) var aspectRatio: Float = 0
    
    /// The near and far plane distances
    private(set) var (near, far): (Float, Float)
    
    /// A unit vector that points in the direction of the camera (which way the camera is looking)
    var cameraDirection: simd_float3 { -simd_float3(simdTransform.columns.0) /* Column 0 is a the vector i-hat-prime */ }
    
    /// A unit vector that points perpendicular and to the right of the direction of the camera in the frame of the camera (j-hat-prime)
    var cameraPlaneXUnitVector: simd_float3 { simd_float3(simdTransform.columns.1) /* Column 1 is a the vector j-hat-prime */ }
    
    /// A unit vector that points perpendicular and up from the direction of the camera in the frame of the camera (k-hat-prime)
    var cameraPlaneYUnitVector: simd_float3 { simd_float3(simdTransform.columns.2) /* Column 2 is a the vector k-hat-prime */ }
    
    /// Whether or not the camera can be controlled from within the program outside
    /// of the control of the user
    ///
    /// The default value is `true`, meaning that the camera node can only move via calls by the user
    var isControlledByUser: Bool = true
    
    /// The user entity controlling this camera in the scene
    weak var lakitu: MSLakitu?
    
    // MARK: - View Matricies -
    
    /// The view-projection matrix, converting points into NDC space
    /// from world space
    var viewProjectionMatrix: matrix_float4x4 { orthographicPerspectiveTransform * viewTransform }
    
    /// The transform to apply to everything in the scene (all world points) to convert all positions to be defined with respect to the camera's frame
    var viewTransform: matrix_float4x4 { simdTransform.inverse }
    
    /// The perspective transform which transforms points in the
    /// the frame of the camera to Normalized Device Coordinates (NDC(
    final var orthographicPerspectiveTransform: matrix_float4x4 { .init(fov: fov, aspectRatio: aspectRatio, near: near, far: far) }
    
    // The camera is assumed to be initialized looking down the x-axis
    init(aspectRatio ratio: Float, near: Float = 0.1, far: Float = 10000, fov: Angle = .π / 2) {
        self.near = near
        self.far = far
        
        // Given the near and far planes, calculate the field of view angles of the
        super.init(positionInParent: .zero, eulerAngles: .unrotated)
        
        // Set the fov and wedgeFov properly
        refocus(newAspectRatio: ratio)
    }
    
    // MARK: - Methods -
    
    /// Updates the field of view of the camera based on the new aspect ratio
    func refocus(newAspectRatio aspectRatio: Float) { self.aspectRatio = aspectRatio }
    
    /// All of the nodes visible to the camera in the scene within which it resides
    final func visibleNodesToRasterizer() -> [MSNode] { [] }
    
    // MARK: - Movements in the Scene -
    
    /// Moves the camera in the scene with the specified value
    final func move(by displacement: simd_float3) { position += displacement }
    
    /// Moves the camera forward (in the direction it is looking) by the specified amount
    final func moveForward(by distance: Float) { position += distance * cameraDirection }
    
    /// Moves the camera right by the specified amount
    final func moveRight(by distance: Float) { position += distance * cameraPlaneXUnitVector }
    
    /// Moves the camera up by the specified amount
    final func moveUp(by distance: Float) { position += distance * cameraPlaneYUnitVector }
    
    /// Rotates the camera (changes the roll of the camera)
    final func roll(by deltaR: Float) { eulerAngles.roll += deltaR }
    
    /// Changes the tilt of the camera
    final func tilt(by deltaP: Float) { eulerAngles.pitch += deltaP }
    
    /// Changes the yaw of the camera
    final func rotate(by deltaY: Float) { eulerAngles.yaw += deltaY }
}
