//
//  Created by Maxwell Pirtle on 8/23/20
//  Copyright © 2020 Maxwell Pirtle. All rights reserved.
//
//  Abstract:
//  Loads data from .obj files and creates `MTLModel` instances to be rendered
    

import Foundation
import ModelIO
import MetalKit

final class MSModelLoader {

    struct LoadFailure: Error {
        private init() {}
        
        /// The underlying error object
        var specificError: Error?
        
        // Cases
        static let unsupportedFileExtension = LoadFailure()
        static let meshFailure = LoadFailure()
        static let fileNotFound = LoadFailure()
    }
    
    // MARK: - Properties -
    
    /// The device to write metal buffers to (the device should live longer than this instance)
    private(set) unowned var device: MTLDevice
    
    /// The default vertex descriptor to use
    private var mdlVertexDescriptor: MDLVertexDescriptor
    
    init(device: MTLDevice, mdlVertexDescriptor: MDLVertexDescriptor) {
        self.device = device
        self.mdlVertexDescriptor = mdlVertexDescriptor
    }
    
    // MARK: - Model Loading -
    
    /// Models that have previously been loaded. This is used
    /// in the event that a model has already been loaded
    private static var cachedModels: [MSModel] = []
    
    /// Loads a file from the asset catalog with the given name and extension
    func loadModel(fileNamed name: String) throws -> MSModel {
        
        // Get the file URL from the path
        let path = name.pathSplit
        guard let url = Bundle.main.url(forResource: path.name, withExtension: path.`extension`) else
        {
            fatalError("Model not loaded. Ensure that the proper name is referenced")
        }
        
        // Get a model if it has already been loaded
        if let cachedModel = MSModelLoader.cachedModels.first(where: { $0.modelURL == url }) { return cachedModel }
        
        // Otherwise, load the model and add it to the cache
        let model = try loadModel(atUrl: url)
        MSModelLoader.cachedModels.append(model)
        
        return model
    }
    
    /// Load a model for a particular geometry (preferred)
    func loadModel(geometryClass: MSGeometryClass) throws -> MSModel {
        // Get the file URL from the path
        guard let url = Bundle.main.url(forResource: geometryClass.name, withExtension: geometryClass.fileExtension) else
        {
            fatalError("Model not loaded. Ensure that the proper name is referenced")
        }
        
        // Get a model if it has already been loaded
        if let cachedModel = MSModelLoader.cachedModels.first(where: { $0.modelURL == url }) { return cachedModel }
        
        // Otherwise, load the model and add it to the cache
        let model = try loadModel(atUrl: url, geometryClass: geometryClass)
        MSModelLoader.cachedModels.append(model)
        
        return model
    }
}

extension MSModelLoader {
    /// Creates the given model from the file extension provided
    private func loadModel(atUrl url: URL, geometryClass: MSGeometryClass? = nil) throws -> MSModel {
        let allocator = MTKMeshBufferAllocator(device: device)
        let mdlAsset = MDLAsset(url: url, vertexDescriptor: mdlVertexDescriptor, bufferAllocator: allocator)
  
        do {
            // Try to load the mesh data at the URL
            let meshes = try MTKMesh.newMeshes(asset: mdlAsset, device: device)
            let modelMeshes = zip(meshes.modelIOMeshes, meshes.metalKitMeshes).map { MSModelMesh(mtkMesh: $1, mdlMesh: $0, device: self.device) }
            let model = MSModel(modelURL: url, meshes: modelMeshes, geometryClass: geometryClass)
            
            // Load the texture data for the model meshes
            let textureAllocator = MTKTextureLoader(device: device)
            model.loadMeshTextures(with: textureAllocator)
            
            // Load textures if the mesh was successfully created
            mdlAsset.loadTextures()
            
            return model
        }
        catch let error {
            var loadError = LoadFailure.meshFailure
            loadError.specificError = error
            
            // Pass the error along
            throw loadError
        }
    }
}
