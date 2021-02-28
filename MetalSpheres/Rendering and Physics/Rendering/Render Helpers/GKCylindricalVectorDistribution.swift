//
//  Created by Maxwell Pirtle on 12/23/20
//  Copyright © 2020 Maxwell Pirtle. All rights reserved.
//
//  Abstract:
//
    

import GameplayKit.GKRandomDistribution

/// A `GKCylindricalVectorDistribution` describes a distribution of 3D vector
/// components in cylindrical coordinates. Each component's magnitude is described
/// by its own probability distribution passed into this distribution
final class GKCylindricalVectorDistribution: NSObject {
    
    private(set) var radialDistribution: GKRandomDistribution
    private(set) var thetaDistribution: GKRandomDistribution
    private(set) var zDistribution: GKRandomDistribution
    
    // The range of radii values
    private(set) var radii: ClosedRange<Float>
    private(set) var zValues: ClosedRange<Float>
    private(set) var thetaValues: ClosedRange<Float>
    
    // MARK: Initializers
    
    /// Creates a new vector distribution, returning a vector whosed radial and angular
    /// values follow the distributions provided
    init(radii: ClosedRange<Float>,
         thetaValues: ClosedRange<Float> = Float(0.0)...Float(2.0 * .pi),
         zValues: ClosedRange<Float>,
         radialDistribution: GKRandomDistribution,
         thetaDistribution: GKRandomDistribution,
         zDistribution: GKRandomDistribution)
    {
        self.radialDistribution = radialDistribution
        self.thetaDistribution = thetaDistribution
        self.zDistribution = zDistribution
        self.radii = radii
        self.thetaValues = thetaValues
        self.zValues = zValues
    }
    
    /// Creates a new vector distribution whose components extend to the given values.
    /// The range from 0.0 to a particular value is split according to the granularity
    convenience init(minRadius: Float = 0.0, maxRadius: Float, maxTheta: Float = 2 * .pi, minZ: Float, maxZ: Float, granularity: Int = 200)
    {
        self.init(radii: minRadius...maxRadius,
                  thetaValues: 0.0...maxTheta,
                  zValues: minZ...maxZ,
                  radialDistribution: .init(lowestValue: 0, highestValue: granularity),
                  thetaDistribution: .init(lowestValue: 0, highestValue: granularity),
                  zDistribution: .init(lowestValue: 0, highestValue: granularity))
    }
    
    /// Returns a new randomized vector
    func nextVector() -> SIMD3<Float> {
        let r = radii.randomValue(withRandomGenerator: radialDistribution)
        let theta = thetaValues.randomValue(withRandomGenerator: thetaDistribution)
        let z = zValues.randomValue(withRandomGenerator: zDistribution)
        
        // Calculate the unit vectors
        let rHat = simd_float3(cos(theta), sin(theta), 0)
        let zHat = simd_float3(0, 0, 1)
        
        return r * rHat + z * zHat
    }
}

