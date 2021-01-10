//
//  Created by Maxwell Pirtle on 11/23/20
//  Copyright © 2020 Maxwell Pirtle. All rights reserved.
//
//  Abstract:
//
    

// C Headers
#import "MSUniforms.h"

// Metal Headers
#import <metal_stdlib>
using namespace metal;

namespace {
    constant constexpr float4 axisColors[3] =
    {
        { 1.0, 0.0, 0.0, 1.0 },
        { 0.0, 0.0, 1.0, 1.0 },
        { 0.0, 1.0, 0.0, 1.0 }
    };
}

#pragma mark - Axis Drawing -

struct AxisFragment { float4 position [[position]]; };


vertex AxisFragment axis_vertex(const device float3 *verticies          [[ buffer(0) ]],
                                constant MSUniforms &uniforms           [[ buffer(1) ]],
                                ushort vid [[vertex_id]])
{
    return AxisFragment { .position = uniforms.cameraUniforms.viewProjectionMatrix * float4(verticies[vid], 1) };
}

fragment float4 axis_fragment(AxisFragment frag         [[ stage_in ]],
                              constant ushort &col_id   [[ buffer(1) ]])
{
    return axisColors[col_id];
}
