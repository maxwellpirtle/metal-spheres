//
//  Created by Maxwell Pirtle on 12/23/20
//  Copyright © 2020 Maxwell Pirtle. All rights reserved.
//
//  Abstract:
//
    

import GameplayKit.GKRandomDistribution

final class GKCylindricalComponentsDistribution: NSObject {
    
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
        let r = radialDistribution.nextUniform()
        
        return .zero
    }
}
