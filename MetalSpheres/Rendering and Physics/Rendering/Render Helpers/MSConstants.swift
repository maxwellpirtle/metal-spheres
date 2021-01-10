//
//  Created by Maxwell Pirtle on 11/23/20
//  Copyright © 2020 Maxwell Pirtle. All rights reserved.
//
//  Abstract:
//  Renders the coordinate axes in the center of the scene (world position zero)
    

import Metal.MTLCommandBuffer
 
struct MSConstants {
    
    // MARK: - Properties -
    
    static let xyplane: [simd_float3] =
    [
        .zero, .iHat, .jHat,
        .zero, .iHat, -.jHat,
        .zero, -.iHat, .jHat,
        .zero, -.iHat, -.jHat,
    ]
    
    static let xzplane: [simd_float3] =
    [
        .zero, .iHat, .kHat,
        .zero, .iHat, -.kHat,
        .zero, -.iHat, .kHat,
        .zero, -.iHat, -.kHat,
    ]
    
    static let yzplane: [simd_float3] =
    [
        .zero, .jHat, .kHat,
        .zero, .jHat, -.kHat,
        .zero, -.jHat, .kHat,
        .zero, -.jHat, -.kHat,
    ]
    
    /// The number of frames ahead of the GPU the CPU can be writing to
    static let framesInFlight: Int = 3
    
    /// The maximum number of particles that can be simulated at once
    /// The maximum number of particle possible
    static var maximumParticlesInSimulation: Int { Int(MAX_PARTICLES) }
    

    // Camera Properties
    static let forwardMotionIncrement     = Float(0.1)
    static let backwardMotionIncrement    = Float(0.1)
    static let upwardMotionIncrement      = Float(0.1)
    static let cameraRollIncrement        = Float(0.1)
    static let cameraKeyPitchIncrement    = Float(0.05)
    static let cameraKeyYawIncrement      = Float(0.05)
    static let cameraMousePitchIncrement  = Float(0.005)
    static let cameraMouseYawIncrement    = Float(0.005)
}
