//
//  Created by Maxwell Pirtle on 11/8/20
//  Copyright © 2020 Maxwell Pirtle. All rights reserved.
//
//  Abstract:
//  A set of properties that is used to describe a physical object
    

import simd.base

struct MSPhysicsDescriptor {
    
    typealias Kilograms = Double
    typealias Coulombs = Double
    
    /// The mass of the object in KG
    let mass: Kilograms = 1.0
    
    /// The electric charge of the object in Coulombs
    let charge: Coulombs = 0.0
    
    /// The position of the object descibed in absolute space
    let position: simd_float3
    
    /// The velocity of the object described in absolute space
    let velocity: simd_float3
    
    /// The acceleration of the object
    let acceleration: simd_float3
}
