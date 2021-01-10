//
//  Created by Maxwell Pirtle on 9/2/20
//  Copyright © 2020 Maxwell Pirtle. All rights reserved.
//
//  Abstract:
//
    

import Foundation
import Relativity

// We are working with vectors in R^3 space (3-tuples), itself a vector space
typealias MS3TupleVectorType = simd_float3
typealias MSVector = MS3TupleVectorType

// Vectors of this type are the coordiantes different bases representing other points in space
typealias MSCylindricalCoordinates = MSVector
typealias MSSphericalCoordinates = MSVector
typealias MSAxisScaleVector = simd_float3

extension RTransform {
    init(position: MSVector, eulerAngles: EulerAngles, scale: MSAxisScaleVector) { self.init(position: position, eulerAngles: eulerAngles, coordinateScales: scale) }
    
    /// Useful conversition between an `RTransform` and a `matrix_float4x4`
    var simdMatrix: matrix_float4x4 { .init(transform: self) }
}

extension RShearTransform {
    /// Useful conversition between an `RShearTransform` and  a `matrix_float4x4`
    var simdMatrix: matrix_float4x4 { .init(shearTransform: self) }
}

extension MSUniforms {
    /// A convenience init
    /// - Returns:
    ///   A new uniforms instance, or if not camera is present `nil`
    init!(scene: MSParticleScene) {
        // Ensure a camera exists
        guard scene.camera != nil else { return nil }
        let cameraUniforms = MSCameraUniforms(camera: scene.camera!)
        
        // Retrieve the size of the particle
        let particleUniforms = MSParticleUniforms(particleSize: type(of: scene).particleScaleFactor)
        
        self = .init(cameraUniforms: cameraUniforms, particleUniforms: particleUniforms)
    }
}

extension MSCameraUniforms {
    /// Create a new camera uniforms object from a camera node
    init(camera: MSCameraNode) {
        self = .init(cameraPositionInParent: camera.position,
                     worldTransform: camera.simdTransform,
                     viewTransform: camera.viewTransform,
                     projectionMatrix: camera.orthographicPerspectiveTransform,
                     viewProjectionMatrix: camera.viewProjectionMatrix)
    }
}
