//
//  Created by Maxwell Pirtle on 9/3/20
//  Copyright © 2020 Maxwell Pirtle. All rights reserved.
//
//  Abstract:
//  A type that manages the production of nodes for the scene
    
import ModelIO.MDLVertexDescriptor
import Metal.MTLDevice

class MSSceneController: NSObject {
    /// The scene that the controller is currently managing
    weak var scene: MSScene? { didSet { scene?.controller = self } }
    
    /// Loads models for the scene
    let modelLoader: MSModelLoader
    
    // MARK: Initializers
    
    init(scene: MSScene) {
        let renderer = scene.renderer
        
        self.scene = scene
        self.modelLoader = MSModelLoader(device: renderer.device, mdlVertexDescriptor: renderer.assetsMDLVertexDescriptor)
        super.init()
        
        // Set the controller to be self
        scene.controller = self
    }
    
    // MARK: - High Level Interaction -
}
