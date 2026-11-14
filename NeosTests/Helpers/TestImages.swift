import CoreGraphics
import Foundation
@testable import Neos

/// Images drawn with Core Graphics alone, so the image tests run on macOS and iOS.
enum TestImages {
    static func solid(red: CGFloat, green: CGFloat, blue: CGFloat, size: Int = 8) -> PlatformImage {
        let context = CGContext(
            data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        context.setFillColor(CGColor(red: red, green: green, blue: blue, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: size, height: size))
        return PlatformImage(cgImage: context.makeImage()!, pixelSize: CGSize(width: size, height: size))
    }

    static func png(red: CGFloat = 1, green: CGFloat = 0.6, blue: CGFloat = 0) -> Data {
        solid(red: red, green: green, blue: blue).pngRepresentation()!
    }
}
