//
//  Created by Maxwell Pirtle on 11/8/20
//  Copyright © 2020 Maxwell Pirtle. All rights reserved.
//
//  Abstract:
//
    
#pragma once

#pragma mark - Physics Properties -

#ifndef __METAL_VERSION__
#import <simd/simd.h>
#endif

#define MAX_PARTICLES 2e4

/// A structure that holds information
/// about a physical object
typedef struct {
    
    /// The mass of the object
    float mass;
    
    /// The charge of the particle
    float charge;
    
    // MARK: - Linear -
    
    /// The location of the object in 3D space
    simd_float3 position;
    
    /// The rate of change of position, defined
    /// as a vector within some vector space
    simd_float3 velocity;
    
    /// The rate of change of velocity
    simd_float3 acceleration;
    
    // MARK: - Angular  -
    
    /// The angular velocity vector of the particle
    simd_float3 angular_velocity;
    
    /// The angular acceleration vector of the particle
    simd_float3 angular_acceleration;
    
} Particle;


/// Describes the center of mass of a body
typedef struct CenterOfMass {
    
    /// The location of the center of mass
    const simd_float3 pos;
    
    /// The total mass of the system under consideration
    const float total_mass;
    
    // Conversion function in Metal
#ifdef __METAL_VERSION__
    CenterOfMass(simd_float3 pos, float total_mass) : pos(pos), total_mass(total_mass) {}
    explicit CenterOfMass(float4 encoded_com) : CenterOfMass(encoded_com.xyz, encoded_com.w) {}
#endif
    
} CenterOfMass;

