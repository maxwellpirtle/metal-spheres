//
//  Created by Maxwell Pirtle on 11/8/20
//  Copyright © 2020 Maxwell Pirtle. All rights reserved.
//
//  Abstract:
//  A particle in a scene that can interact with other particles via gravitational fields or electrostatic fields
    

import Relativity

class MSParticleNode: MSSpriteNode {
    
    // MARK: - Particle-specific Properties-
    
    /// The parent node of a particle must be a scene instance
    override func added(to node: MSNode) {
        precondition(node is MSScene)
    }
    
    // MARK: - Physics Properties -
    
    /// Physical properties describing the object. This does not constitute a
    /// physics body by any means, but merely only specifies information about the node
    private(set) var physicalState: MSPhysicalState = .default()
    
    // MARK: - Initializers -
    
    required init(model:                     MSModel?,
                  parent:                    MSNode? = nil,
                  positionInParent position: MSVector = .zero,
                  eulerAngles:               EulerAngles = .unrotated,
                  coordinateScales:          MSAxisScaleVector = .one)
    {
        super.init(model: model, parent: parent, positionInParent: position, eulerAngles: eulerAngles, coordinateScales: coordinateScales)
        self.physicalState.position = position
        self.physicalState.particle = self
    }

    required init(model: MSModel?, parent: MSNode? = nil, positionInParent position: MSVector = .zero, shearTransform: RShearTransform) {
        super.init(model: model, parent: parent, positionInParent: position, shearTransform: shearTransform)
        self.physicalState.position = position
        self.physicalState.particle = self
    }
    
    convenience init(modelType: MSGeometryClass, loader: MSModelLoader, transform: RTransform = .absolute) {
        self.init(model: try! loader.loadModel(geometryClass: modelType), positionInParent: transform.position, eulerAngles: transform.eulerAngles, coordinateScales: transform.coordinateScales)
        self.physicalState.position = transform.position
        self.physicalState.particle = self
    }
    

    // MARK: - Methods -
    
    override func removeFromParent() {
        
        // If we are in a particle scene, let the scene know
        if let scene = scene as? MSParticleScene {
            scene.universeDelegate?.particle(self, wasRemovedFromUniverse: scene)
        }
        
        super.removeFromParent()
    }
}
