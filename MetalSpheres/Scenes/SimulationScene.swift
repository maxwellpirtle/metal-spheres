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
    
    var time: Timer!
    
    override func didMove(to view: MSSceneView) {
        super.didMove(to: view)
        
        // Create models and fill the scene
        let loader = controller.modelLoader
        
//        let startingLocations: [MSVector] = [.init(-10.0, 0.0, 0.0), .init(10.0, 0.0, 0.0), .init(10.0, -10.0, 0.0), .init(10.0, 10.0, 0.0), .init(0.0, 10.0, 0.0)]
//
//
//        for loc in startingLocations {
//            let moon = MSParticleNode(modelType: .particle, loader: loader)
//            moon.name = "Moon"
//            moon.physicalState.mass = 1000
//            moon.coordinateScales = .init(0.0625, 0.0625, 0.0625)
////            moon.shearTransform = .init(position: loc,
////                                        xNew: ObliqueAxis(scale: 1, theta: .pi / 2, phi: .pi / 4),
////                                        yNew: ObliqueAxis(scale: 3, theta: .pi / 3, phi: .pi / 4),
////                                        zNew: ObliqueAxis(scale: 0.5, theta: 0, phi: -.pi / 4))
//            moon.position = loc
//            moon.physicalState.position = loc
//            addChild(moon)
//        }
        
        let source = GKARC4RandomSource()
        let random = GKGaussianDistribution(randomSource: source, mean: 10.0, deviation: 3.0)
        print(random.highestValue)
        let unifo = GKRandomDistribution()
        
//        let source =
        
        for _  in 0..<1000 {
            let moon = MSParticleNode(modelType: .particle, loader: loader)
            moon.name = "Moon"
            moon.physicalState.mass = random.nextUniform() * 5.0
//            moon.physicalState.charge = random.nextUniform() * 19.0 //* (unifo.nextBool() ? 1.0 : -1.0)
            
            moon.coordinateScales = .init(0.02, 0.02, 0.02)
//            moon.physicalState.charge = 0.1
            //            moon.shearTransform = .init(position: loc,
            //                                        xNew: ObliqueAxis(scale: 1, theta: .pi / 2, phi: .pi / 4),
            //                                        yNew: ObliqueAxis(scale: 3, theta: .pi / 3, phi: .pi / 4),
            //                                        zNew: ObliqueAxis(scale: 0.5, theta: 0, phi: -.pi / 4))
            let pos = simd_float3.random(in: -10.0...10.0)
            moon.position = pos
            moon.physicalState.position = pos
            moon.physicalState.velocity = .random(in: -0.5...0.5)
            addChild(moon)
        }
        
        for _ in 0..<200 {
            let bigMoon = MSParticleNode(modelType: .particle, loader: loader)
            bigMoon.name = "Moon"
            bigMoon.physicalState.mass = 20
            
            bigMoon.coordinateScales = .init(1, 1, 1)
            let pos = simd_float3.random(in: -10.0...10.0)
            bigMoon.position = pos
            bigMoon.physicalState.position = pos
            bigMoon.physicalState.velocity = simd_float3(0.0, 0.0, 0.0)
            addChild(bigMoon)
        }
        
//
//        time = Timer(timeInterval: 5.0, repeats: true, block: { _ in
//            DispatchQueue.main.async { [unowned self] in
//                let moon = MSParticleNode(modelType: .particle, loader: loader)
//                moon.name = "Moon"
//                moon.physicalState.mass = 100
//                moon.coordinateScales = .init(0.1, 0.1, 0.1)
//                moon.position = .random(in: -1.0...1.0)
//                addChild(moon)
//                print("Set")
//            }
//        })
//        RunLoop.main.add(time, forMode: .default)
//        DispatchQueue.main.asyncAfter(deadline: .now() + 7.0) { [unowned self] in
//            let moon = MSParticleNode(modelType: .particle, loader: loader)
//            moon.name = "Moon"
//            moon.physicalState.mass = 100
//            moon.coordinateScales = .init(0.1, 0.1, 0.1)
//            moon.position = .random(in: -1.0...1.0)
//            addChild(moon)
//            print("Set")
//        }
        
//        renderer.particleRenderer.state.isElectromagnetismEnabled = true
        renderer.particleRenderer.state.isGravityEnabled = true
//
//        let sum = (0..<800).reduce(Float(0.0)) { prev, _ in
//            prev + random.nextUniform() * 19.0
//        }
//
//        print(sum / 800)
        
//        renderer.particleRenderer.state.isElectromagnetismEnabled = true

        let camera = MSFixedCameraNode(aspectRatio: Float(view.frame.width / view.frame.height))
        camera.sphericalCoordinates = .init(r: 20, theta: 0, phi: 1.5 * .pi / 4)
//        camera.coordinateScales = .init(2.0, 2.0, 2.0)
        
//        camera.shearTransform = .init(position: camera.position,
//                                      xNew: ObliqueAxis(scale: 1.0, theta: 0, phi: .pi / 2),
//                                      yNew: ObliqueAxis(scale: 1.0, theta: .pi / 2, phi: .pi / 2),
//                                      zNew: ObliqueAxis(scale: 1.0, theta: 0, phi: 0))
        
//        camera.position = .init(0, 5, 0)
//        camera.eulerAngles.yaw = .pi / 2

        addChild(camera)
        
        // Set the camera
        self.camera = camera
    }
    
    override func willRender(_ deltaTime: TimeInterval) {
        super.willRender(deltaTime)
    }
}
