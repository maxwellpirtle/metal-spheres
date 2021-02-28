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

#define MAX_PARTICLES 1e5
#define MAX_PARTICLE_MASS 5.0f//100.0f

typedef struct {
    float mass;
    float charge;
    
    // MARK: Linear Motion
    
    simd_float3 position;
    simd_float3 velocity;
    simd_float3 acceleration;
    
    // MARK: Angular Motion
    
    simd_float3 angular_velocity;
    simd_float3 angular_acceleration;
    
} Particle;

/// Represents a particle stub
typedef struct {
    float mass;
    float charge;
    simd_float3 position;
} ThreadgroupParticle;


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

