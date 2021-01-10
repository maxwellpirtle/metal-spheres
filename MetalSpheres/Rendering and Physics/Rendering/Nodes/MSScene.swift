//
//  Created by Maxwell Pirtle on 8/23/20
//  Copyright © 2020 Maxwell Pirtle. All rights reserved.
//
//  Abstract:
//  The context within which everything is rendered
    

import Foundation
import Relativity

class MSScene: MSNode {
    
    // MARK: - Properties -
    
    /// A reference to the camera node that is used as a reference to render the scene
    var camera: MSCameraNode?
    
    /// A reference to the controller object for creating nodes
    unowned var controller: MSSceneController!

    /// A reference to the `MSRenderer` object driving the scene
    private(set) unowned var renderer: MSRendererCore

    /// The reference to the model loader
    private var modelLoader: MSModelLoader { controller.modelLoader }
    
    // MARK: - Scene Properties -
    
    final override var position: MSVector {
        didSet {
            preconditionFailure("Setting the scene position is not permitted")
        }
    }
    
    final override var coordinateScales: MSAxisScaleVector {
        didSet {
            preconditionFailure("Setting the scene's coordinate scales is not permitted")
        }
    }
    
    final override var eulerAngles: EulerAngles {
        didSet {
            preconditionFailure("Setting the scene's Euler angles is not permitted")
        }
    }
    
    final override var shearTransform: RShearTransform? {
        didSet {
            preconditionFailure("Setting the scene's shear transform is not permitted")
        }
    }
    
    // MARK: - Initializers -
    
    required init(renderer: MSRendererCore) {
        self.renderer = renderer
        super.init(positionInParent: .zero, eulerAngles: .init())
    }
    
    // MARK: - Methods -
    
    func didMove(to view: MSSceneView) {}
    func willMove(from view: MSSceneView) {}
    func viewDidResize(_ view: MSSceneView, oldSize: CGSize) { camera?.refocus(newAspectRatio: Float(view.aspectRatio)) }
    
    func willRender(_ deltaTime: TimeInterval) {
        
        // --- Dispatch Camera Updates --- \\
        camera?.lakitu?.update(deltaTime)
        
    }
}
