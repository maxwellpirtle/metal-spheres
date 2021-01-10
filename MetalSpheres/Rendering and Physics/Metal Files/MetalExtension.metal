//
//  Created by Maxwell Pirtle on 12/6/20
//  Copyright © 2020 Maxwell Pirtle. All rights reserved.
//
//  Abstract:
//
    

// C Headers


#import <metal_stdlib>
using namespace metal;

namespace metal {
    /// Linearly interpolates between two values, assuming that the
    inline half3 interpolate(half3 a, half3 b, half percent) {
        half p = clamp(percent, 0.0h, 1.0h);
        return (1.0h - p) * a + p * b;
    }
    
    /// Linearly interpolates between two values, assuming that the
    inline half4 interpolate(half4 a, half4 b, half percent) {
        half p = clamp(percent, 0.0h, 1.0h);
        return (1.0h - p) * a + p * b;
    }
}

