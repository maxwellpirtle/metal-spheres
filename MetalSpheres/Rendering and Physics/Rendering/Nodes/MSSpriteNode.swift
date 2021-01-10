//
//  Created by Maxwell Pirtle on 9/4/20
//  Copyright © 2020 Maxwell Pirtle. All rights reserved.
//
//  Abstract:
//  A node with properties that are rendered
    
import Relativity
import Metal.MTLRenderCommandEncoder

class MSSpriteNode: MSNode {
    
    // MARK: - Model Properties -
    
    /// The underlying model object that is represented by the node (if any)
    var model: MSModel?
    
    /// Whether or not the given node preserves its size when changing parents
    var hasPersistantDimensions: Bool = true
    
    // MARK: - Initializers -
    
    required init(model:                     MSModel?,
                  parent:                    MSNode? = nil,
                  positionInParent position: MSVector = .zero,
                  eulerAngles:               EulerAngles = .unrotated,
                  coordinateScales:          MSAxisScaleVector = .one)
    {
        self.model = model
        super.init(parent: parent, positionInParent: position, eulerAngles: eulerAngles, coordinateScales: coordinateScales)
    }
    
    required init(model:                     MSModel?,
                  parent:                    MSNode? = nil,
                  positionInParent position: MSVector = .zero,
                  shearTransform:            RShearTransform)
    {
        self.model = model
        super.init(parent: parent, positionInParent: position, shearTransform: shearTransform)
    }
    
    convenience init(modelType: MSGeometryClass, loader: MSModelLoader, transform: RTransform = .absolute) {
        self.init(model: try! loader.loadModel(geometryClass: modelType), positionInParent: transform.position, eulerAngles: transform.eulerAngles, coordinateScales: transform.coordinateScales)
    }
    
    /// A factory method that creates a duplicate node that refers to the same model. The node is not immediataely added to the same parent however
    final func newReferenceSprite() -> MSSpriteNode {
        prefersObliqueTransform ?
            .init(model: model, parent: nil, shearTransform: shearTransform!)
            :
            .init(model: model, parent: nil, positionInParent: .zero, eulerAngles: .init(), coordinateScales: coordinateScales)
    }
}

