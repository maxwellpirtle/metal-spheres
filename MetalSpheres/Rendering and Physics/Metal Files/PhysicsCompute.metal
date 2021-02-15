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
#define GRAVITY_CONSTANT_NORMALIZED 5.0e-5f

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
    
    /// Calculates an inverse square force acting in the direction specified.
    /// The function assumes that the positions are defined within the
    /// same coordinate system. If the particles are at distance 0, the force is
    /// `NaN` with the fast math compiler flag set
    inline float3 inv_sqr_force(const thread float3 displacement, const thread float scale)
    {
        // An inverse square law is of the form
        //
        // vec(F) = C / r^2 * unit_vec(between)
        //
        // where r = distance between the two objects.
        //
        // This gives us equivalently
        //
        // vec(F) = C / r^3 * vec(between)
        //
        // Now r = sqrt(r^2), so 1 / r^3 = 1 / (sqrt (r^2))^3 = [ 1 / (sqrt(r^2)) ]^3
        //
        // Computing the inverse square root of a value is much faster than computing the distance and simply diving by its cube
        // since dividing by a runtime value is extremely slow. Hence the reason for the below method

        // r^2
        const auto sqr_distance = dot(displacement, displacement);
        
        // The inverse-distance between the two particles == 1 / sqrt(r^2)
        const auto inv = rsqrt(sqr_distance);
        
        // The inverse cube of the distance == [1 / sqrt(r^2) ]^3
        const auto inv3 = inv * inv * inv; // ILP
        
        // The "magnitude" of the force on the particle. In reality, this is not the true magnitude
        // but a value that makes the calculation on the GPU much faster (see the above note)
        const auto pseudo_magnitude { scale * inv3 };
        
        return pseudo_magnitude * displacement;
    }
    
    /// Calculates the gravitational force acting on the first of the two
    /// objects with their respective masses and positions due to the second.
    inline float3 newtonGravitationalForceOn(const device Particle &objA, const device Particle &objB)
    {
        return inv_sqr_force(objB.position - objA.position, GRAVITY_CONSTANT_NORMALIZED * objA.mass * objB.mass);
    }
    
    /// Calculates the electrostatic force acting on the first of the two
    /// objects with their respective charges and positions due to the second.
    inline float3 electrostaticForceOn(const device Particle &objA, const device Particle &objB)
    {
        // Electrostatics dictates that two particles of the same charge repulse; hence the displacement
        // is defaulted to point away from the first object
        return inv_sqr_force(objA.position - objB.position, COULOMB_CONSTANT_NORMALIZED * objA.charge * objB.charge);
    }
}

