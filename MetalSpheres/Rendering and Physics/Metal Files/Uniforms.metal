//
//  Created by Maxwell Pirtle on 9/4/20
//  Copyright © 2020 Maxwell Pirtle. All rights reserved.
//
//  Abstract:
//  C structures that hold data the is constant throughout a render pass or for a single model
    

#import <metal_stdlib>

using namespace metal;

#define SIMD_ILP_STATEMENT(x) x; \
x; \
x; \
x; \
x; \
x; \
x; \
x;

// MARK: Constants

static constant float4x4 modelNDCToWorld {
    { 0, 1, 0, 0 },
    { 0, 0, 1, 0 },
    { -1, 0, 0, 0 },
    { 0, 0, 0, 1 }
};

static constant float3x3 modelNDCToWorld3x3 {
    { 0, 1, 0 },
    { 0, 0, 1 },
    { -1, 0, 0 },
};
