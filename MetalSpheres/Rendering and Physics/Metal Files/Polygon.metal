//
//  Created by Maxwell Pirtle on 9/6/20
//  Copyright © 2020 Maxwell Pirtle. All rights reserved.
//
//  Abstract:
//
    
#import <metal_matrix>

constant constexpr float M_PI = 3.14159265358979323846264338327950288;
constant constexpr float2 iHat = float2(1, 0);

namespace metal {
    
    // The sawtooth function
    METAL_FUNC float sawtooth(float f) { return f - floor(f); }
    
    /// A polygon with `s` sides oriented with `transform` that converts points from the system within which the polygon resides.
    /// The frame "attached" to the polygon has an X axis passing through a vertex of the polygon. `circR` refers to the radius
    /// of the circumscribed circle that passes through each of the verticies
    struct polygon {
        const uint s;
        const float circR;
        const float3x3 transform;
        
        // Constructor
        polygon(uint s, float circR, float3x3 transform) : s(s), circR(circR), transform(transform) {}
        
        // `pt` is assumed to be a point in the parent system. `conatins` excludes the set of points along the edges of the polygon
        bool contains(float2 pt);
    };
}


bool metal::polygon::contains(float2 pt) {
    // The position in the frame of the polygon
    float2 poly_pt = (transform * float3(pt, 1)).xy;
    
    // Using the law of sines, we can determine the distance that is allowed (see below)
    float sqDist = distance_squared(0, pt);
    
    // Outside circle that circumscibes the polygon
    if (sqDist > circR * circR) return false;
    
    // Calculate the angle the point makes with the x axis in the frame of the polygon.
    // The wedgeAngle is the angle that is formed between two verticies connected by an edge
    float wedgeAngle = 2 * M_PI / s;
    float ptAngle = dot(poly_pt, iHat);
    float deltaTheta = sawtooth(ptAngle / wedgeAngle) * wedgeAngle;
    
    // Calculate the maximum distance squared at this angle that is allowed at this angle relative to
    // line-segment joining the `floor(ptAngle / wedgeAngle)`th (kth) vertex with the center of the polygon.
    // This is done by viewing the polygon from a frame whose X-axis is the line from the center of the polygon
    /// to the kth vertex. Draw line segment L1 from the kth vertex to the (k+1)th vertex and mark its endpoints K and L respectively.
    /// Draw line segment L2 from the center of the polygon to the point under consideration and mark L2's intersection with L1
    /// as "A". If the center of the triangle is "O", then triangle "OKL" is isosceles with vertex angle `wedgeAngle` and
    /// base angle B = M_PI / 2 - wedgeAngle / 2 (since 2B + wedge = M_PI). Triangle "OAK" contains `deltaTheta` and B.
    /// Thus, the third angle is M_PI - B - deltaTheta. `maxR` results from the law of sines with this third angle and the
    /// base angle B' contained within triangle "OAK".
    float maxR = circR * sin(M_PI / 2 - wedgeAngle / 2) / sin(M_PI / 2 + wedgeAngle / 2 - deltaTheta);
    
    return sqDist < maxR * maxR;
}
