//
//  Created by Maxwell Pirtle on 11/29/20
//  Copyright © 2020 Maxwell Pirtle. All rights reserved.
//
//  Abstract:
//  Describes assets in the asset catalog. Every model comes with its own
//  geometry class. Any model that reuses a geometry class should specify this
    

import Foundation

struct MSGeometryClass {
    
    /// An extension to an asset in the catalog
    enum Extension: String {
        case obj = "obj"
    }
    
    private init(name: String, extension: Extension) { self.name = name; self.extension = `extension` }
    
    /// The name of the file referenced by the asset
    let name: String
    
    /// The extension of the asset
    let `extension`: Extension
    
    /// The extension as a string
    var fileExtension: String { `extension`.rawValue }
    
    /// The path to the asset in the main bundle
    var filepath: String { name + fileExtension }
    
    // MARK: - Cases -
    
    /// The moon asset
    static let particle = MSGeometryClass(name: "Moon2K", extension: .obj)
    
    /// The train asset
    static let train = MSGeometryClass(name: "train", extension: .obj)
}

extension MSGeometryClass {
    
    /// Whether or not two geometry classes are the same
    func isEqual(to gc: MSGeometryClass) -> Bool { gc.name == name }
}
