//
//  Created by Maxwell Pirtle on 12/23/20
//  Copyright © 2020 Maxwell Pirtle. All rights reserved.
//
//  Abstract:
//
    

import GameplayKit.GKRandomDistribution

final class GKCylindricalVectorDistribution: NSObject {
    
    private(set) var radialDistribution: GKRandomDistribution
    private(set) var thetaDistribution: GKRandomDistribution
    private(set) var zDistribution: GKRandomDistribution
    
    /// Creates a new vector distribution, returning a vector whosed radial and angular
    /// values follow the distributions provided
    init(radialDistribution: GKRandomDistribution, thetaDistribution: GKRandomDistribution, zDistribution: GKRandomDistribution) {
        self.radialDistribution = radialDistribution
        self.thetaDistribution = thetaDistribution
        self.zDistribution = zDistribution
    }
    
    /// Returns a new randomized vector
    func nextVector() -> SIMD3<Float> {
        let r = Float(radialDistribution.highestValue) * radialDistribution.nextUniform()
        let theta = Float(thetaDistribution.highestValue) * thetaDistribution.nextUniform()
        let z = Float(zDistribution.highestValue) * zDistribution.nextUniform()
        
        
        // Calculate the unit vectors
        let rHat = simd_float3(r * cos(theta), r * sin(theta), 0)
        let thetaHat = simd_float3(-r * sin(theta), r * cos(theta), 0)
        let zHat = simd_float3(0, 0, 1)
        
        return r * rHat
        
    }
}
