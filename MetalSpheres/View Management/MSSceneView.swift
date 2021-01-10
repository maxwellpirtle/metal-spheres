//
//  Created by Maxwell Pirtle on 8/25/20
//  Copyright © 2020 Maxwell Pirtle. All rights reserved.
//
//  Abstract:
//  A custom MTKView subclass that holds a reference to a scene instance that should be rendered
    

import MetalKit.MTKView

class MSSceneView: MTKView {
    /// The scene instance that is referenced by this view
    var scene: MSScene?

    override var acceptsFirstResponder: Bool { true }
}
