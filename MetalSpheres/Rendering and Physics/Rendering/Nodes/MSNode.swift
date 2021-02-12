//
//  Created by Maxwell Pirtle on 9/2/20
//  Copyright © 2020 Maxwell Pirtle. All rights reserved.
//
//  Abstract:
//  An abstract reference to an object in a scene
    
import Metal.MTLRenderCommandEncoder
import Relativity
import Accelerate

class MSNode: NSObject {
    // MARK: - Properties -
    
    /// The name of the node
    var name: String?
    
    /// The scene within which the node resides
    final var scene: MSScene? { parent is MSScene? ? parent as? MSScene : parent?.scene }
    
    /// The parent node of this node (if any)
    private(set) var parent: MSNode?
    
    /// Descendants of this node. These nodes are affected by the positioning of this node with respect to its own parent
    private(set) var children: [MSNode] = []
    
    /// The parent node of the parent node (if any)
    final var grandparent: MSNode? { parent?.parent }
    
    /// Returns the parent node N generations deep (if there is such a node)
    func parent(at generation: Int) -> MSNode? {
        generation == 0 ? self : parent?.parent(at: generation - 1)
    }
    
    // MARK: - Tranformation Properties -
    
    /*
        NOTE:
        -   Position is relative to the parent node
        -   Euler angles are intrinsic and measured by copying the parent's frame and using the orientation of the node with respect to that frame (look at the i' axis)
        -   Coordinate scales represent a scale for descendants AND this node (meaning that this node would appear distorted to its own parent)
     
        When imagining how a node is positioned with respect to its parent, begin by aligning the
        coordinate axes of the child with those of the parent. Scale the axes, rotate the
        child node, and then translate the child node. The result in an active
        interpretation of converting a point in the child node's coordinate system
        to the parent's coordinate system
     
        Parent's coordinate system -> Coordinate system THIS node resides in
        Node's coordinate system -> Coordinate system THIS NODE'S CHILDREN reside in (the system it defines ITSELF)
    */
    var position: MSVector
    var eulerAngles: EulerAngles
    var coordinateScales: MSAxisScaleVector
    private var rTransform: RTransform { .init(position: position, eulerAngles: eulerAngles, scale: coordinateScales) }
    
    /**
     
        If the node prefers to use oblique coordinates, the `simdTransform` will read from the `rShearTransform`
        as opposed to the `rTransform` property
    */
    final var prefersObliqueTransform: Bool { shearTransform != nil }
    
    /// Sheer coordinate scales as appropriate. If a value is non-nil, the node is assumed
    /// to prefer this transform over the classical transform without oblique axes
    var shearTransform: RShearTransform?
    
    /// The transformation which places points into the parent's coordinate system within which this node resides
    final var simdTransformToCommonReferenceFrame: matrix_float4x4 { parent != nil ? parent!.simdTransform : .identity_matrix }
    
    /// The transformation which, if premultiplied with points in the node's coordinate system, would convert them to points in absolute space
    final var simdTransform: matrix_float4x4 {
        parent != nil ?
            parent!.simdTransform * (prefersObliqueTransform ? shearTransform!.simdMatrix : rTransform.simdMatrix)
            :
            prefersObliqueTransform ? shearTransform!.simdMatrix : rTransform.simdMatrix
    }
    
    /// The transform describing the translation of the node with respect to its parent
    final var simdTranslation: matrix_float4x4 { .init(translation: position) }
    
    /// The transform describing the scale applied to the node's coordinate system
    final var simdScale: matrix_float4x4 { .init(translation: position) }
    
    /// The transform describing the rotation of the node with respect to its parent
    final var simdRotation: matrix_float4x4 { .init(pitch: eulerAngles.pitch, roll: eulerAngles.roll, yaw: eulerAngles.yaw) }


    // MARK: - Initializers -
    
    init(parent: MSNode? = nil, positionInParent position: MSVector, eulerAngles: EulerAngles, coordinateScales: MSAxisScaleVector = .one) {
        self.position = position
        self.eulerAngles = eulerAngles
        self.coordinateScales = coordinateScales
        
        super.init()
        
        // Add the child to the parent
        parent?.addChild(self)
    }
    
    init(parent: MSNode? = nil, positionInParent position: MSVector, shearTransform: RShearTransform) {
        self.position = position
        self.eulerAngles = .unrotated
        self.coordinateScales = .one
        self.shearTransform = shearTransform
        
        super.init()
        
        // Add the child to the parent
        parent?.addChild(self)
    }
    
    // MARK: - Parent Methods -
    
    /// Called by parent nodes to let the children know it was added to this given node
    func added(to node: MSNode) {}
    
    /// Adds a node to this node's hierarchy
    func addChild(_ child: MSNode) {
        guard child.parent == nil else { fatalError("Attempted to add node \(child) to \(self) that already has a parent node \(child.parent!)") }
        
        child.parent = self
        children.append(child)
        child.added(to: self)
    }
    
    /// Removes the node from the hierarchy it is in
    func removeFromParent() { parent?.children.removeAll { $0 === self }; parent = nil }
    
    // MARK: - Node Searching -
    
    /// An option that specifies how a search should be carried out
    /// when looking for nodes in the tree
    @frozen enum SearchMode {
        
        /// All direct descendants
        case directDescendants
        
        /// All direct descendants and their
        /// children
        case allDescendants
        
    }
    
    /// Finds the first child nodes with the name specified. This is a relatively
    /// expensive operation, and so should only be performed when necessary
    final func childNode(withName name: String, searchMode: SearchMode) -> MSNode? {
        switch searchMode {
        case .allDescendants:
            
            // Check the children first for a match
            if let child = childNode(withName: name, searchMode: .directDescendants) {
                return child
            }
            
            // If there isn't a match with any of the children,
            // check the other descendants
            for c in children {
                if let child = c.childNode(withName: name, searchMode: .allDescendants) {
                    return child
                }
            }
            
            return nil
            
        case .directDescendants:
            
            return children.first { child in
                child.name == name
            }
            
        }
    }
    
    /// Conveniently finds all direct children with the given geometry
    final func children(withGeometryClass gc: MSGeometryClass, searchMode: SearchMode) -> [MSSpriteNode] {
        switch searchMode {
        case .allDescendants:
            
            return children.reduce([MSSpriteNode]())
            { prev, node in
                
                prev + node.children(withGeometryClass: gc, searchMode: .allDescendants)
                
            } + children(withGeometryClass: .particle, searchMode: .directDescendants)
            
        case .directDescendants:
            
            return children
                .compactMap { $0 as? MSSpriteNode }
                .filter { $0.model?.geometryClass != nil }
                .filter { $0.model!.geometryClass!.isEqual(to: gc) }

        }
    }
    
    // MARK: - Conversion Methods -
    
    /// Converts a point in the coordinate system of this node to absolute space
    final func convertToScene(_ location: simd_float3) -> simd_float3 {
        simd_float3(simdTransform * simd_float4(location))
    }
    
    /// Converts a point in absolute space to the coordinate system of this node
    final func convertFromScene(_ location: simd_float3) -> simd_float3 {
        simd_float3(simdTransform.inverse * simd_float4(location))
    }
    
    /// Converts a point in the coordinate system of this node to the coordinate system of another node
    final func convert(_ location: simd_float3, to otherNode: MSNode) -> simd_float3 {
        otherNode.convertFromScene(convertToScene(location))
    }
}
