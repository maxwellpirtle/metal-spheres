
//
//  Created by Maxwell Pirtle on 9/3/20
//  Copyright © 2020 Maxwell Pirtle. All rights reserved.
//
//  Abstract:
//  A representation of the vertex and material data of piece of a model
    

import MetalKit

typealias MTKMeshGroup = [MTKMesh]
typealias MTKSubmeshGroup = [MTKSubmesh]
typealias MDLMeshGroup = [MDLMesh]

typealias MSMeshPartitionGroup = [MSModelMesh.Partition]

class MSModelMesh {
    
    /// The model that is represented by this mesh
    weak var model: MSModel?
    
    /// The device that created the `MTKMesh` buffer associated with this mesh
    private(set) unowned var device: MTLDevice
    
    /// The `MTKMesh` object that stores the buffer backing the vertex data
    private(set) var mtkMesh: MTKMesh
    
    /// A set of submesh objects representing the submesh data for each `MDLMesh` loaded from the asset
    private(set) var submeshes: MSMeshPartitionGroup = []
    
    // MARK: Init
    init(mtkMesh: MTKMesh, mdlMesh: MDLMesh, device: MTLDevice) {
        self.mtkMesh = mtkMesh
        self.device = device
        submeshes = zip(mtkMesh.submeshes, mdlMesh.submeshes!).map {
            let submesh = Partition(mtkSubmesh: $0, mdlSubmesh: $1 as! MDLSubmesh, msmesh: self)
            return submesh
        }
    }
}

extension MSModelMesh {
    
    // MARK: - Model Partition -
    
    class Partition {
        /// The `MSModelMesh` instance that holds a reference to this submesh
        private(set) weak var msMesh: MSModelMesh?
        
        /// Holds reference to a `MTLTexture` created with the ModelIO material properties
        struct Texture {
            
            /// The buffer backing the texture data
            private(set) var mtlTexture: MTLTexture?
            
            // Create the texture from the given material
            init(material: MDLMaterial?, allocator: MTKTextureLoader) {
                
            }
        }
        
        /// The texture that coats this surface
        private(set) var texture: Texture?
        
        /// The verticies to draw
        private(set) var mtkSubmesh: MTKSubmesh?
        
        /// The verticies to draw
        private(set) var mdlSubmesh: MDLSubmesh?
        
        /// Loads the texture object and discards the reference to the `MDLSubmesh`
        func loadTexture(_ allocator: MTKTextureLoader) {
            guard let mdlSubmesh = mdlSubmesh else { fatalError("Expected submesh") }
            texture = Texture(material: mdlSubmesh.material, allocator: allocator)
            
            // Remove the reference to the submesh
            self.mdlSubmesh = nil
        }
        
        // MARK: Initializer
        
        init(mtkSubmesh: MTKSubmesh, mdlSubmesh: MDLSubmesh, msmesh: MSModelMesh) {
            // Get the submesh data from the
            self.mtkSubmesh = mtkSubmesh
            self.mdlSubmesh = mdlSubmesh
            self.msMesh = msmesh
        }
    }
    
}
