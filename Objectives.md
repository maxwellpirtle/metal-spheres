# Controls

## WASD - typical movement
## R - Roll the camera
## 

# MetalSpheres: Objectives

The goal of the project:


1. Manipulate metallic spheres moving around in space undergoing electrostatic and gravitational attractions

2. Move around in space as an observer
    a. Pause the simulation and change the simulation speed. Control other aspects of the rendering
    
3. Change sphere properties dynamically. For instance, pause the simulation and change the sphere's mass, charge, velocity, etc. Add spheres on the fly

4. Visualize sphere velocity, position, and acceleration by rendering vectors in Vector Mode


Game plan:


What changes throughout the duration of the program?

1. The location of the spheres and the spheres' properties
2. Whether or not the simulation is paused (simulation state)
3. The number of spheres being rendered and how they look relative to the player
4. The player's view port


How is that change effectuated?

macOS

1. Keyboard presses
2. Buttons
3. Window scene

iOS

1. Presses




# Swift Class Breakdown

macOS

`class MetalSpheresViewController : NSViewController`
    Handle touch interactions
    Updates properties on the scene
    
`class MSNode : NSObject`
    Holds transform data and serves as an interface to objects
    in the scene
    
`class MSScene : MSNode`
    A root node with unit transform and scale. The scene serves as a place to
    store an `MSCameraNode` and details about the scene itself (which objects it contains)

`class MSCameraNode`
    A perspective of a viewer

`class MSRenderer`


# Metal Hierarchy



