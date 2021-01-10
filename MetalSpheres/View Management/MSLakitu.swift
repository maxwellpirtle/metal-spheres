//
//  Created by Maxwell Pirtle on 12/16/20
//  Copyright © 2020 Maxwell Pirtle. All rights reserved.
//
//  Abstract:
//  Just as Lakitu does in Mario, an instance of the MSLakitu class will move the camera in the scene according to commands
    

import Foundation

class MSLakitu: NSObject {
    
    // MARK: - Properties -
    
    /// Describes the current motion of the observer
    struct MotionStatus: OptionSet {
        typealias RawValue = Int
        
        let rawValue: Int
        let key: Character
        
        init(rawValue: Int) { self.rawValue = rawValue; key = Character("?") }
        init(rawValue: Int, key: Character) { self.rawValue = rawValue; self.key = key }
        
        static let movingForward   = MotionStatus(rawValue: 1 << 0, key: Character("w"))
        static let movingBackward  = MotionStatus(rawValue: 1 << 1, key: Character("s"))
        static let movingRight     = MotionStatus(rawValue: 1 << 2, key: Character("d"))
        static let movingLeft      = MotionStatus(rawValue: 1 << 3, key: Character("a"))
        static let movingUp        = MotionStatus(rawValue: 1 << 4, key: Character(" "))
        static let movingDown      = MotionStatus(rawValue: 1 << 5, key: Character("q"))
        static let rollingCCW      = MotionStatus(rawValue: 1 << 6, key: Character("e"))
        static let rollingCW       = MotionStatus(rawValue: 1 << 7, key: Character("r"))
        static let pitchUp         = MotionStatus(rawValue: 1 << 8, key: Character("g"))
        static let pitchDown       = MotionStatus(rawValue: 1 << 9, key: Character("f"))
        static let yawRight        = MotionStatus(rawValue: 1 << 10, key: Character("z"))
        static let yawLeft         = MotionStatus(rawValue: 1 << 11, key: Character("x"))
        
        static let allCases: [MotionStatus] =
        [
            .movingForward, .movingBackward, .movingRight, .movingLeft, .movingUp, .movingDown,
            .rollingCCW, .rollingCW, .pitchUp, .pitchDown, .yawRight, .yawLeft
        ]
        
        /// The motion that should result when the given key is pressed
        static func motion(forKey character: Character) -> MotionStatus? { MotionStatus.allCases.first(where: { $0.key == character }) }
        
        // Allow for switch pattern binding
        static func ~=(pattern: (MotionStatus) -> Bool, value: MotionStatus) -> Bool { pattern(value) }
    }
   
    /// Sensitivity parameters
    var cameraProperties = MSCameraInterfaceParameters()
    
    /// The camera managed by the Lakitu
    private(set) unowned var camera: MSCameraNode!

    /// How this Lakitu is currently moving in the scene
    private(set) var keyMotion: MotionStatus = []
    
    // MARK: - Initializer -
    
    init(camera: MSCameraNode) {
        self.camera = camera
        
        super.init()
        
        // Set the "delegate"
        camera.lakitu = self
    }
    
    
    // MARK: - Updates -
    
    /// Updates the motion of the lakitu based on the key pressed
    func newKeyInput(character: Character) {
        print(character)
        guard let newMotion = MotionStatus.motion(forKey: character) else { return }
        
        // Add this new motion
        keyMotion.formUnion(newMotion)
    }
    
    /// Updates the motion of the lakitu based on the key just unpressed
    func removeKeyInput(character: Character) {
        guard let currentMotion = MotionStatus.motion(forKey: character) else { return }
        
        // Add this new motion
        keyMotion.remove(currentMotion)
    }

    /// Rotates and elevates the camera
    func mouseDragged(deltaX: Float, deltaY: Float) {
        mouseRotate(factor: deltaX)
        mouseTilt(factor: deltaY)
    }
    
    /// Tells the instance to perform any camera updates at this time
    ///
    /// Do not invoke this method yourself except within a scene render loop
    func update(_ deltaTime: TimeInterval) {
        // Motion is a linear combination of the motions provided
        if keyMotion.contains(.movingForward)         { keyedMove(forward: true) }
        if keyMotion.contains(.movingBackward)        { keyedMove(forward: false) }
        if keyMotion.contains(.movingRight)           { keyedMove(right: true) }
        if keyMotion.contains(.movingLeft)            { keyedMove(right: false) }
        if keyMotion.contains(.movingUp)              { keyedMove(up: true) }
        if keyMotion.contains(.movingDown)            { keyedMove(up: false) }
        if keyMotion.contains(.rollingCW)             { keyedRoll(clockwise: true) }
        if keyMotion.contains(.rollingCCW)            { keyedRoll(clockwise: false) }
        if keyMotion.contains(.pitchUp)               { keyedTilt(up: true) }
        if keyMotion.contains(.pitchDown)             { keyedTilt(up: false) }
        if keyMotion.contains(.yawRight)              { keyedRotate(cw: true) }
        if keyMotion.contains(.yawLeft)               { keyedRotate(cw: false) }
    }
    

    // MARK: - Key Movements in the Scene -

    func keyedMove(forward: Bool) {
        let distance = cameraProperties.forwardMotionSensitivity * MSConstants.forwardMotionIncrement
        camera.moveForward(by: forward ? distance : -distance)
    }
    
    func keyedMove(right: Bool) {
        let distance = cameraProperties.rightMotionSensitivity * MSConstants.forwardMotionIncrement
        camera.moveRight(by: right ? distance : -distance)
    }
    
    func keyedMove(up: Bool) {
        let distance = cameraProperties.upMotionSensitivity * MSConstants.upwardMotionIncrement
        camera.moveUp(by: up ? distance : -distance)
    }
    
    func keyedRoll(clockwise: Bool) {
        let deltaR = cameraProperties.rollSensitivity * MSConstants.cameraRollIncrement
        camera.roll(by: clockwise ? deltaR : -deltaR)
    }
    
    func keyedTilt(up: Bool) {
        let deltaP = cameraProperties.pitchSensitivity * MSConstants.cameraKeyPitchIncrement
        camera.tilt(by: up ? deltaP : -deltaP)
    }
    
    func keyedRotate(cw: Bool) {
        let deltaY = cameraProperties.yawSensitivity * MSConstants.cameraKeyYawIncrement
        camera.rotate(by: cw ? deltaY : -deltaY)
    }
    
    /// - Parameters:
    ///   - factor: The scale by which the mouse drag should be scaled
    func mouseTilt(factor: Float) {
        let deltaP = factor * cameraProperties.pitchSensitivity * MSConstants.cameraMousePitchIncrement
        camera.tilt(by: deltaP)
    }
    
    /// - Parameters:
    ///   - factor: The scale by which the mouse drag should be scaled
    func mouseRotate(factor: Float) {
        let deltaY = factor * cameraProperties.yawSensitivity * MSConstants.cameraMouseYawIncrement
        camera.rotate(by: deltaY)
    }
}
