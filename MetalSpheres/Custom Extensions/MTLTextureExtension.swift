//
//  Created by Maxwell Pirtle on 11/29/20
//  Copyright © 2020 Maxwell Pirtle. All rights reserved.
//
//  Abstract:
//
    
import Quartz
import Metal.MTLTexture
import MetalKit.MTKTextureLoader

extension MTLTexture {
    /// Creates an NSImage instance from the contents of a MTLTexture
    /// object
    /// - Parameters:
    ///     - context: The `CIContext` instance to read image data in
    /// - Returns:
    ///     An NSImage instance that can be used with an NSView for display
    func makeNSImage(context: CIContext) -> NSImage? {
        
        // Create a CIImage from the texture using a convenent initializer
        let image = CIImage(mtlTexture: self, options: [CIImageOption.colorSpace : CGColorSpaceCreateDeviceRGB()])!
        if let cgImage = context.createCGImage(image, from: image.extent) { return NSImage(cgImage: cgImage, size: .zero) } else { return nil }
    }
}

extension NSImage {
    /// Converts an NSImage object into a format readable by Metal
    /// - Parameters:
    ///     - descriptor:
    ///     The intended use of the texture
    /// - Precondition:
    ///     The descriptor is checked to ensure that the image fits precisely
    ///     in the texture it is defining
    /// - Returns:
    ///     A new `MTLTexture` allocated on the device specified
    ///     by the processor
    func mtlTexture(device: MTLDevice, usage: MTLTextureUsage) -> MTLTexture? {
        
        // Ensure Cocoa can create a CGImage from this NSImage
        guard let cgImage = cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        
        // Create a texture loader that can load `MTLTexture`s
        let loader = MTKTextureLoader(device: device)
        
        // The loader creates textures fallibly. Handle any errors
        do {
            // Configuration options. These options
            // act as an indirect MTLTextureDescriptor
            let loadOptions: [MTKTextureLoader.Option : Any] =
                [
                    MTKTextureLoader.Option.origin : MTLOriginMake(0, 0, 0),
                    MTKTextureLoader.Option.textureUsage : usage.rawValue,
                    MTKTextureLoader.Option.SRGB : false
                ]
            return try loader.newTexture(cgImage: cgImage, options: loadOptions)
        }
        catch {
            // Do some work
        }
        
        return nil
    }
    
    func mtlTexture(device: MTLDevice, descriptor: MTLTextureDescriptor) -> MTLTexture? {
        
        // Ensure Cocoa can create a CGImage from this NSImage
        guard let cgImage = cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        
        // Initialize constants useful for the colorspace
        let bitsPerComponent = 8
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
        let width = descriptor.width
        let height = descriptor.height
        
        // As per the CGContext specification, passing in `nil` and `bytesPerRow = 0` is valid.
        // This ensures that memory is managed by the function, a much safer paradigm
        guard let context = CGContext(data: nil,
                                      width: width,
                                      height: height,
                                      bitsPerComponent: bitsPerComponent,
                                      bytesPerRow: 0,
                                      space: cgImage.colorSpace!,
                                      bitmapInfo: bitmapInfo) else { return nil }
        
        
        // Transform the image data write into a coordinate
        // system that makes sense to us
        // NOTE:
        // After some testing, the coordinate system to read data starts at the bottom left
        // corner and reads left to right moving up, mapping to a point in a system with origin
        // in the top right
        //  * -- x_write -- -> +
        //  |
        //  y_write
        //  |
        //  |
        //  +
        //
        //  +
        //  |
        //  y_read
        //  |
        //  |
        //  * x_read ---- -> +
        let imageWriteTransform = CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: size.height)
        
        context.concatenate(imageWriteTransform)
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        // Create a new MTLTexture and write the data into it
        let texture = device.makeTexture(descriptor: descriptor)
        let regionSize = MTLSize(width: width, height: height, depth: 1)
        let region = MTLRegion(origin: .init(x: 0, y: 0, z: 0), size: regionSize)
        
        texture?.replace(region: region,
                         mipmapLevel: descriptor.mipmapLevelCount,
                         withBytes: context.data!,
                         bytesPerRow: context.bytesPerRow)
        
        return texture
    }
}
