//
//  Created by Maxwell Pirtle on 8/23/20
//  Copyright © 2020 Maxwell Pirtle. All rights reserved.
//
//  Abstract:
//
    
#ifndef SceneUniforms_h
#define SceneUniforms_h

#include <simd/simd.h>

#pragma mark - Uniforms -

struct MSCameraUniforms {
    
    /// The position of the camera in its parent
    simd_float3 cameraPositionInParent;
    
    /// The transform applied to the camera which
    /// transforms a position at the origin in absolute
    /// space to the equivalent position in absolute space in the
    /// camera's coordinate frame
    matrix_float4x4 worldTransform;
    
    /// Transforms points in absolute space
    /// into the coordinate system of the camera.
    /// That is, places the camera at the center of the
    /// universe. Serves as the inverse to `worldTransform`
    matrix_float4x4 viewTransform;
    
    /// Converts points from the coordinate system
    /// of the camera first into the standard camera frame
    /// and then into NDC coordinates
    matrix_float4x4 projectionMatrix;
    
    /// Both the view and projection matrix combined
    matrix_float4x4 viewProjectionMatrix;
    
};

struct MSParticleUniforms {
    // The size of a single particle. This effectively determines the uniform axis scale
    // that is applied to the particle's coordinate system
    float particleSize;
};

struct MSUniforms {
    struct MSCameraUniforms cameraUniforms;
    struct MSParticleUniforms particleUniforms;
};


#endif /* SceneUniforms_h */

