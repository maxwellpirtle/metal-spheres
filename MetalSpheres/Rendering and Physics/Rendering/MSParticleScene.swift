//
//  Created by Maxwell Pirtle on 11/25/20
//  Copyright © 2020 Maxwell Pirtle. All rights reserved.
//
//  Abstract:
//  A scene that manages a set of particles for rendering
    

import Foundation

class MSParticleScene: MSScene {
    
    /// The size of a single particle in our simulation
    class var particleScaleFactor: Float { 0.02 }
    
    /// A delegate that manages particle work
    weak var universeDelegate: MSUniverseDelegate?
    
    /// Overridden to add support, calling the delegate when particles are added and removed
    override func addChild(_ child: MSNode) {
        super.addChild(child)
        
        if let child = child as? MSParticleNode {
            universeDelegate?.particle(child, wasAddedToUniverse: self)
        }
    }
    
    required init(renderer: MSRendererCore) {
        super.init(renderer: renderer)
        
        // Set the delegate of the particle engine
        universeDelegate = renderer.particleRenderer
    }
}
