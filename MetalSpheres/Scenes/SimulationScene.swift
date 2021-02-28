//
//  Created by Maxwell Pirtle on 9/4/20
//  Copyright © 2020 Maxwell Pirtle. All rights reserved.
//
//  Abstract:s
//  The scene that controls the content for the main gameplay
    

import Foundation
import GameplayKit
import Relativity

class SimulationScene: MSParticleScene {
    
    override func didMove(to view: MSSceneView) {
        super.didMove(to: view)

        // We have 64 * 500 = 32_000 particles in our simulation. Note this is
        // a multiple of the wavefront size on macOS
        let loader = controller.modelLoader
        let particlesInSimulation = 64 * 500
        let cylinderRadius: Float = 10.0
        let cylinderHeight: Float = 0.0
        
        // Compute position and velocity distributions for this scene
        
        // Break the unit circle into 100 different possibilities. We place the points within
        // a cylinder of radius `cylinderRadius` of height `cylinderHeight`
        
        let positionCylindricalDistribution = GKCylindricalVectorDistribution(minRadius: cylinderRadius / 2.0, maxRadius: cylinderRadius, minZ: -cylinderHeight / 2.0, maxZ: cylinderHeight / 2.0)
//        let velocityCylindricalDistribution = GKCylindricalVectorDistribution(maxRadius: 0.0, minZ: 0.0, maxZ: 0.0)
        
        for _ in 0...1000 {
            print(positionCylindricalDistribution.nextVector())
        }
        
        let massDistribution = GKRandomDistribution(lowestValue: 1, highestValue: 100)
        
        for i in 0..<particlesInSimulation {
            let moon = MSParticleNode(modelType: .particle, loader: loader)
            moon.name = "Moon \(i)"
            moon.physicalState.mass = massDistribution.nextUniform() * 5.0
            moon.coordinateScales = .init(0.04, 0.04, 0.04)
            moon.position = positionCylindricalDistribution.nextVector()
            moon.physicalState.velocity = .zero//velocityCylindricalDistribution.nextVector()
            addChild(moon)
        }

        
        let camera = MSFixedCameraNode(aspectRatio: Float(view.aspectRatio))
        camera.sphericalCoordinates = .init(r: 20, theta: 0, phi: 1.5 * .pi / 4)
        addChild(camera)
        
        // Set the camera
        self.camera = camera
    }
    
    override func willRender(_ deltaTime: TimeInterval) {
        super.willRender(deltaTime)
    }
}
