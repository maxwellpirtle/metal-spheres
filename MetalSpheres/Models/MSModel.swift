//
//  Created by Maxwell Pirtle on 8/23/20
//  Copyright © 2020 Maxwell Pirtle. All rights reserved.
//
//  Abstract:
//  Represents a single model loaded from a .obj file or equivalent
    

import MetalKit

class MSModel {
    
    // MARK: - Properties -
    
    /// The name of the model (user related)
    var name: String?
    
    #if DEBUG
    /// A name that can be referenced to while debugging
    var debugName: String?
    #endif
    
    /// The URL that holds the data for this model
    let modelURL: URL?
    
    /// The type of model referenced by this instance
    let geometryClass: MSGeometryClass?
    
    /// The mesh buffer data for this object
    private(set) var meshes: [MSModelMesh]
    
    // MARK: Initializer
    
    init(modelURL: URL, meshes: [MSModelMesh], geometryClass: MSGeometryClass? = nil) {
        self.modelURL = modelURL
        self.meshes = meshes
        self.geometryClass = geometryClass
    
        // Set the model of the mesh as this model
        meshes.forEach { $0.model = self }
    }
    
    // MARK: - Rendering Methods -
    
    /// Loads the textures for each mesh
    func loadMeshTextures(with allocator: MTKTextureLoader) {
        for mesh in meshes {
            for submesh in mesh.submeshes {
                submesh.loadTexture(allocator)
            }
        }
    }


//    func render(with encoder: MTLRenderCommandEncoder) {
//        for mesh in meshes {
//            for vb in mesh.mtkMesh.vertexBuffers.map({ $0.buffer }) {
//                encoder.setVertexBuffer(vb, offset: 0, index: 0)
//
//                for submesh in mesh.submeshes {
//                    let mtkSubmesh = submesh.mtkSubmesh!
//                    encoder.drawIndexedPrimitives(type: .triangle,
//                                                  indexCount: mtkSubmesh.indexCount,
//                                                  indexType: mtkSubmesh.indexType,
//                                                  indexBuffer: mtkSubmesh.indexBuffer.buffer,
//                                                  indexBufferOffset: mtkSubmesh.indexBuffer.offset)
//                }
//            }
//        }
//    }
}
