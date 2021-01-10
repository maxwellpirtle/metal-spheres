//
//  Created by Maxwell Pirtle on 11/28/20
//  Copyright © 2020 Maxwell Pirtle. All rights reserved.
//
//  Abstract:
//  A type that controls the state of the universe
    

import Foundation

protocol MSUniverseDelegate: AnyObject {
    func particle(_ particle: MSParticleNode, wasAddedToUniverse scene: MSScene)
    func particle(_ particle: MSParticleNode, wasRemovedFromUniverse scene: MSScene)
}
