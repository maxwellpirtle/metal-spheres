//
//  Created by Maxwell Pirtle on 11/9/20
//  Copyright © 2020 Maxwell Pirtle. All rights reserved.
//
//  Abstract:
//  Describes how particle data should update per-frame. Describes what forces are at play in the
//  physics pass update
    

import Foundation

struct MSParticleRendererState {
    
    static let `default`: MSParticleRendererState = .init()
    
    // MARK: - Properties -
    
    /// Whether or not the simulation has been paused
    var isPaused = false
    
    /// Whether or not a physics simulation is occurring
    var isSimulatingPhysics: Bool { !isPaused && (isGravityEnabled || isElectromagnetismEnabled)  }
    
    /// Whether or not gravity is active
    var isGravityEnabled = true
    
    /// Whether or not electrostatic forces are active
    var isElectromagnetismEnabled = false
    
    /// Whether or not to draw each particle as a point as opposed to a sphere
    var pointParticles = true

    // MARK: - Methods -
}
