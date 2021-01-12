//
//  Created by Maxwell Pirtle on 11/10/20
//  Copyright © 2020 Maxwell Pirtle. All rights reserved.
//
//  Abstract:
//
    
#import <metal_stdlib>
#import "PhysicsKernel.h"

using namespace metal;

#pragma mark - Constants -

#define GRAVITY_CONSTANT 6.67430e-11f
#define GRAVITY_CONSTANT_NORMALIZED 5.0e-3f

#define COULOMB_CONSTANT 8.9875517923e9f
#define COULOMB_CONSTANT_NORMALIZED 5.0e-3f

#pragma mark - Computational Methods -

namespace PhysicsCompute {
    
    // Calculates the center of mass of a system of particles
    inline CenterOfMass COM(const thread Particle *particles, ushort pcount)
    {
        auto M_system = 0.0f;
        auto W_system = static_cast<float3>(0.0f);
        
        // Sum the contributions of each particle to the COM
        for (ushort i = 0; i < pcount; i++) {
            M_system += particles[i].mass;
            W_system += particles[i].mass * particles[i].position;
        }
        
        return { M_system / W_system, M_system };
    }
    
    // Calculates the center of mass of a system of particles. The fourth index in the
    // vector represents the total mass of the system
    template<size_t N>
    METAL_FUNC CenterOfMass COM(const thread array<Particle, N> &array)
    {
        return COM(array.data(), array.size());
    }
    
#pragma mark - Newtonian Methods -
    
    inline float3 pos_increment(const device float3 &position, const device float3 &velocity, const device float3 &acceleration, const thread float delta_time)
    {
        return position + delta_time * velocity;
    }
    
    inline float3 vel_increment(const device float3 &velocity, const device float3 &acceleration, const thread float delta_time)
    {
        return velocity + delta_time * acceleration;
    }
    
    inline void project_in_time(device Particle &particle, const device float3 &force, const thread float dt)
    {
        const float3 new_pos { pos_increment(particle.position,
                                             particle.velocity,
                                             particle.acceleration,
                                             dt) };

        const float3 new_vel { vel_increment(particle.velocity,
                                             particle.acceleration,
                                             dt) };

        const float3 new_accel { force / particle.mass };

        particle.position = new_pos;
        particle.velocity = new_vel;
        particle.acceleration = new_accel;
    }
    
    /// Calculates the gravitational force acting on the first of the two
    /// objects with their respective masses and positions due to the second.
    /// The function assumes that the positions are defined within the
    /// same coordinate system. If the particles are at distance 0, the force is
    /// `NaN`
    inline float3 newtonGravitationalForceOn(const device Particle &objA, const device Particle &objB)
    {
        // Get the unit vector directed from the first to the second.
        // This is the proper direction (attactive after all)
        const auto norm_join_vect { normalize(objB.position - objA.position) };

        const auto scene_distance { distance_squared(objA.position, objB.position) };
        const auto magnitude { GRAVITY_CONSTANT_NORMALIZED * objA.mass * objB.mass / scene_distance };

        return magnitude * norm_join_vect;
    }
    
    /// Calculates the electrostatic force acting on the first of the two
    /// objects with their respective charges and positions due to the second.
    /// The function assumes that the positions are defined within the
    /// same coordinate system. If the particles are at distance 0, the force is
    /// `NaN`
    inline float3 electrostaticForceOn(const device Particle &objA, const device Particle &objB)
    {
        // Get the unit vector directed from the second to the first (away from the first).
        // This is the direction if the particles have the same charge
        const auto norm_join_vect { normalize(objA.position - objB.position) };
        
        const auto scene_distance { distance_squared(objA.position, objB.position) };
        const auto magnitude { COULOMB_CONSTANT_NORMALIZED * objA.charge * objB.charge / scene_distance };
        
        return magnitude * norm_join_vect;
    }
}

