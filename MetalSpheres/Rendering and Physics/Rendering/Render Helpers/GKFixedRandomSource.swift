//
//  Created by Maxwell Pirtle on 2/27/21
//  Copyright © 2021 Maxwell Pirtle. All rights reserved.
//
//  Abstract:
//
    

import GameplayKit.GKRandomSource

/// A `GKUniformRandomSource` generates a fixed constant value each
/// time it is queried to generate a new random number
final class GKFixedRandomSource: GKRandomSource {
    
    /// The constant value that is returned by the source
    private var uniformValue: Int = 0
    
    // Create a new fixed-value random source with the given number
    init(uniformValue: Int = 0) {
        self.uniformValue = uniformValue
        super.init()
    }
    required init(coder aDecoder: NSCoder) { super.init(coder: aDecoder) }
    
    override func nextInt() -> Int { uniformValue }
    override func nextUniform() -> Float { uniformValue == 0 ? 0.0 : 1.0 }
    override func nextBool() -> Bool { uniformValue == 0 }
    
    override func nextInt(upperBound: Int) -> Int {
        guard uniformValue <= upperBound else {
            fatalError("A uniform distribution with uniform return \(uniformValue) cannot generate a value of at most \(upperBound)")
        }
        return uniformValue
    }
}

/// A `GKFixedDistribution` describes a distribution of values
/// that is constant across all samplings
final class GKFixedDistribution: GKRandomDistribution {
    // Create a new uniform distribution with the following value
    init(uniformValue: Int = 0) {
        super.init(randomSource: GKFixedRandomSource(uniformValue: uniformValue), lowestValue: uniformValue, highestValue: uniformValue + 1)
    }
}
