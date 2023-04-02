//
//  Resizer.swift
//  VImage
//
//  Created by Victor Melo on 08/04/20.
//  Copyright © 2020 Victor Melo. All rights reserved.
//
//
// Based on this article: https://medium.com/ymedialabs-innovation/resizing-techniques-and-image-quality-that-every-ios-developer-should-know-e061f33f7aba

import UIKit
import CoreGraphics
import CoreImage
import Accelerate

public enum ResizingType {
    case uiKit
    case coreGraphics
    case coreImage
    case vImage
}

public struct Resizer {
    
    public static func resize(_ inputImage: UIImage, size:CGSize, type: ResizingType = .vImage) -> UIImage? {

        let outputImage: UIImage?
        
        switch type {
        case .uiKit:
            outputImage = resizeUIKit(image: inputImage, size: size)
        case .coreGraphics:
            outputImage = resizeCoreGraphics(image: inputImage, size: size)
        case .coreImage:
            outputImage = resizeCoreImage(image: inputImage, size: size)
        case .vImage:
            outputImage = resizeVImage(image: inputImage, size: size)
        }
        
        return outputImage
    }
    
}

// MARK: - UIKit

private extension Resizer {
    static func resizeUIKit(image: UIImage, size:CGSize) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(size, true, image.scale)
        image.draw(in: CGRect(origin: CGPoint.zero, size: size))
        
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return resizedImage
    }

}

//// MARK: - CoreGraphics

private extension Resizer {
    static func resizeCoreGraphics(image: UIImage, size:CGSize) -> UIImage? {
        guard let cgImage = image.cgImage else { return nil }
        guard let colorSpace = cgImage.colorSpace else { return nil }
        
        let bitsPerComponent = cgImage.bitsPerComponent
        let bytesPerRow = cgImage.bytesPerRow
        let bitmapInfo = cgImage.bitmapInfo

        guard let context = CGContext(data: nil, width: Int(size.width), height: Int(size.height), bitsPerComponent: bitsPerComponent, bytesPerRow: bytesPerRow, space: colorSpace, bitmapInfo: bitmapInfo.rawValue) else { return nil }
        
        context.interpolationQuality = .high

        context.draw(cgImage, in: CGRect(origin: CGPoint.zero, size: size))

        return context.makeImage().flatMap { UIImage(cgImage: $0) }
    }
}


// MARK: - CoreImage
private extension Resizer {
    static func resizeCoreImage(image: UIImage, size: CGSize) -> UIImage? {
        guard let cgImage = image.cgImage else { return nil }
        let scale = (Double)(size.width) / (Double)(image.size.width)
        let image = UIKit.CIImage(cgImage:cgImage)

        let filter = CIFilter(name: "CILanczosScaleTransform")!
        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(NSNumber(value:scale), forKey: kCIInputScaleKey)
        filter.setValue(1.0, forKey:kCIInputAspectRatioKey)
        let outputImage = filter.value(forKey: kCIOutputImageKey) as! UIKit.CIImage

        let context = CIContext(options: [CIContextOption.useSoftwareRenderer: false])
        
        guard let contextCgImage = context.createCGImage(outputImage, from: outputImage.extent) else { return nil }
    
        let resizedImage = UIImage(cgImage: contextCgImage)
        return resizedImage
    }
}

// MARK: - vImage

private extension Resizer {
    static func resizeVImage(image: UIImage, size: CGSize) -> UIImage? {
        guard let cgImage = image.cgImage else { return nil }

        var format = vImage_CGImageFormat(bitsPerComponent: 8, bitsPerPixel: 32, colorSpace: nil,
                                          bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.first.rawValue),
                                          version: 0, decode: nil, renderingIntent: CGColorRenderingIntent.defaultIntent)
        var sourceBuffer = vImage_Buffer()
        defer {
            sourceBuffer.data.deallocate()
        }

        var error = vImageBuffer_InitWithCGImage(&sourceBuffer, &format, nil, cgImage, numericCast(kvImageNoFlags))
        guard error == kvImageNoError else { return nil }

        // create a destination buffer
        let destWidth = Int(size.width)
        let destHeight = Int(size.height)
        let bytesPerPixel = cgImage.bitsPerPixel / 8
        let destBytesPerRow = destWidth * bytesPerPixel
        let destData = UnsafeMutablePointer<UInt8>.allocate(capacity: destHeight * destBytesPerRow)
        defer {
            destData.deallocate()
        }
        var destBuffer = vImage_Buffer(data: destData, height: vImagePixelCount(destHeight), width: vImagePixelCount(destWidth), rowBytes: destBytesPerRow)

        // scale the image
        error = vImageScale_ARGB8888(&sourceBuffer, &destBuffer, nil, numericCast(kvImageHighQualityResampling))
        guard error == kvImageNoError else { return nil }

        // create a CGImage from vImage_Buffer
        let destCGImage = vImageCreateCGImageFromBuffer(&destBuffer, &format, nil, nil, numericCast(kvImageNoFlags), &error)?.takeRetainedValue()
        guard error == kvImageNoError else { return nil }

        // create a UIImage
        let resizedImage = destCGImage.flatMap { UIImage(cgImage: $0, scale: 0.0, orientation: image.imageOrientation) }
        return resizedImage
    }
}
