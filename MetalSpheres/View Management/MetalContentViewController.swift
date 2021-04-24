//
//  Created by Maxwell Pirtle on 8/23/20
//  Copyright © 2020 Maxwell Pirtle. All rights reserved.
//
//  Abstract:
//  A view controller that is responsible for managing the main application portion of the content
//  in the main window
    

#if os(macOS)
import Cocoa
#endif
import MetalKit.MTKView
import Relativity

#if os(macOS)
class MetalContentViewController: NSViewController {
    
    // MARK: - Properties -
    
    /// The `MSSceneView` instance whose content is managed by this controller
    var sceneView: MSSceneView { view as! MSSceneView }
    
    /// The scene that is processed and rendered
    var scene: MSScene! { sceneController.scene }
    
    /// An `MSRendererCore` instance that is used to render the scene
    var renderer: MSRendererCore!
    
    /// An object that manages node creation for the scene
    var sceneController: MSSceneController!
    
    /// Manages the user interaction with the camera
    var lakitu: MSLakitu!
    
    
    // MARK: - View Loaded -

    override func viewDidLoad() {
        super.viewDidLoad()
    
        guard let view = view as? MSSceneView else { fatalError("View must be a subclass of `MTKSceneView`") }
        guard let device = MTLCreateSystemDefaultDevice() else { fatalError("Expected GPU") }
    
        view.device = device
        view.colorPixelFormat = .bgra8Unorm
        view.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1.0)
        view.clearDepth = 1.0
        view.depthStencilPixelFormat = .depth32Float

        renderer = try! MSRendererCore(view: view)
        
        // Configure a custom scene
        let scene = SimulationScene(renderer: renderer)
        sceneController = MSSceneController(scene: scene)
        view.scene = scene
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
        
        // Forward messages to the scene
        scene?.didMove(to: sceneView)
        
        // We expect the scene to have a camera at this point to create a lakitu to control it
        guard let camera = scene.camera else { preconditionFailure("Camera expected at display time") }
        
        lakitu = MSLakitu(camera: camera)
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
        
        // Dispatch a size update
        renderer.mtkView(sceneView, drawableSizeWillChange: sceneView.drawableSize)
    }
    
    // MARK: - User Interaction -
    
    override var acceptsFirstResponder: Bool { true }
    
    override func keyDown(with event: NSEvent) {
        super.keyDown(with: event)
        
        guard let keyedCharacters = event.characters?.map({$0}) else { return }
        
        // Inform the Lakitu to move
        keyedCharacters.forEach { lakitu.newKeyInput(character: $0) }
    }
    
    override func keyUp(with event: NSEvent) {
        super.keyUp(with: event)
        
        guard let keyedCharacters = event.characters?.map({$0}) else { return }
        
        // Inform the Lakitu to move
        keyedCharacters.forEach { lakitu.removeKeyInput(character: $0) }
    }

    override func mouseDragged(with event: NSEvent) {
        super.mouseDragged(with: event)
        lakitu.mouseDragged(deltaX: Float(event.deltaX), deltaY: Float(event.deltaY))
    }
    
    override func rotate(with event: NSEvent) {
        super.rotate(with: event)
        
        print("rotate")
    }
    
    override func swipe(with event: NSEvent) {
        super.swipe(with: event)
        
        print("Swi[")
    }
    
    override func magnify(with event: NSEvent) {
        super.magnify(with: event)
        
        print("A")
    }
    
    // MARK: User Interaction
    
    @IBAction func requestedSimulationPause(_ sender: NSMenuItem) {
        
        // Pause/unpause the current simulation
        renderer.pauseSimulation()
        
        // Query if the simulation is now paused
        let paused = renderer.isPaused
        
        // If we have requested to pause,
        sender.title = { (isPaused: Bool) in isPaused ? InteractionConstants.pauseSimulationLabel : InteractionConstants.resumeSimulationLabel }(paused)
        
    }
    
    @IBAction func toggleCoordinateFrameVisibility(_ sender: NSMenuItem) {
        
    }
    
    @IBAction func togglePointParticleSetting(_ sender: NSMenuItem) {

        // Toggle/untoggle point particles
        renderer.togglePointParticleRendering()
        
        // Query if the simulation is now paused
        let points = renderer.isRenderingParticlesAsPoints
        
        // If we have requested to pause,
        sender.title = { (points: Bool) in points ? InteractionConstants.togglePointParticleLabel : InteractionConstants.toggleSphericalParticleLabel }(points)
    }
}
#elseif os(iOS)
class MetalContentViewController: UIViewController {
    
    // MARK: - Properties -
    
    /// The `MSSceneView` instance whose content is managed by this controller
    var sceneView: MSSceneView { view as! MSSceneView }
    
    /// The scene that is processed and rendered
    var scene: MSScene! { sceneController.scene }
    
    /// An `MSRendererCore` instance that is used to render the scene
    var renderer: MSRendererCore!
    
    /// An object that manages node creation for the scene
    var sceneController: MSSceneController!
    
    /// Manages the user interaction with the camera
    var lakitu: MSLakitu!
    
    
    // MARK: - View Loaded -
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        guard let view = view as? MSSceneView else { fatalError("View must be a subclass of `MTKSceneView`") }
        guard let device = MTLCreateSystemDefaultDevice() else { fatalError("Expected GPU") }
        
        view.device = device
        view.colorPixelFormat = .bgra8Unorm
        view.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1.0)
        view.clearDepth = 1.0
        view.depthStencilPixelFormat = .depth32Float
        
        renderer = try! MSRendererCore(view: view)
        
        // Configure a custom scene
        let scene = SimulationScene(renderer: renderer)
        sceneController = MSSceneController(scene: scene)
        view.scene = scene
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Forward messages to the scene
        scene?.didMove(to: sceneView)
        
        // We expect the scene to have a camera at this point to create a lakitu to control it
        guard let camera = scene.camera else { preconditionFailure("Camera expected at display time") }
        
        lakitu = MSLakitu(camera: camera)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // Dispatch a size update
        renderer.mtkView(sceneView, drawableSizeWillChange: sceneView.drawableSize)
    }
}

#endif
