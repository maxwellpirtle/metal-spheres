//
//  Created by Maxwell Pirtle on 11/8/20
//  Copyright © 2020 Maxwell Pirtle. All rights reserved.
//
//  Abstract:
//  A set of properties that is used to describe a physical object
    

import simd.base

final class MSPhysicalState {

    typealias Kilograms = Float
    typealias Coulombs = Float
    typealias PhysicsKernelParticle = Particle
    
    /// The particle whose physical state is described by this object
    unowned var particle: MSParticleNode?
    
    /// A default configuration
    static func `default`() -> MSPhysicalState {
        MSPhysicalState(mass: 10.0,
                        charge: 0.0,
                        position: .zero,
                        velocity: .zero,
                        acceleration: .zero,
                        angularVelocity: .zero,
                        angularAcceleration: .zero)
    }
    
    /// The mass of the object in KG
    var mass: Kilograms
    
    /// The electric charge of the object in Coulombs
    var charge: Coulombs
    
    /// The position of the object descibed in absolute space
    var position: simd_float3 {
        didSet {
            particle?.position = position
        }
    }
    
    /// The velocity of the object described in absolute space
    var velocity: simd_float3
    
    /// The acceleration of the object
    var acceleration: simd_float3
    
    /// The angular velocity vector of the particle
    var angularVelocity: simd_float3
    
    /// The angular acceleration vector of the particle
    var angularAcceleration: simd_float3
    
    /// A representation of the state as a C struct that can be input
    /// into a Metal compute kernel
    var kernelState: PhysicsKernelParticle {
        .init(mass: mass,
              charge: charge,
              position: position,
              velocity: velocity,
              acceleration: acceleration,
              angular_velocity: angularVelocity,
              angular_acceleration: angularAcceleration)
    }
    
    // MARK: - Initializers -
    
    init(mass: Kilograms = 1.0,
         charge: Coulombs = 0,
         position: simd_float3 = .zero,
         velocity: simd_float3 = .zero,
         acceleration: simd_float3 = .zero,
         angularVelocity: simd_float3 = .zero,
         angularAcceleration: simd_float3 = .zero)
    {
        self.mass = mass
        self.charge = charge
        self.position = position
        self.velocity = velocity
        self.acceleration = acceleration
        self.angularVelocity = angularVelocity
        self.angularAcceleration = angularAcceleration
    }
    
    // MARK: - Methods -
    
    func updateState(_ state: PhysicsKernelParticle) {
        self.mass = state.mass
        self.charge = state.charge
        self.position = state.position
        self.velocity = state.velocity
        self.acceleration = state.acceleration
        self.angularVelocity = state.angular_velocity
        self.angularAcceleration = state.angular_acceleration
    }
}
