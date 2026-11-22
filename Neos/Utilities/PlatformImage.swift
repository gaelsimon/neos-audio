import SwiftUI
#if os(macOS)
import AppKit

typealias PlatformImage = NSImage
#else
import UIKit

typealias PlatformImage = UIImage
#endif

extension Image {
    init(platformImage: PlatformImage) {
        #if os(macOS)
        self.init(nsImage: platformImage)
        #else
        self.init(uiImage: platformImage)
        #endif
    }
}

extension PlatformImage {
    /// Size in points equals size in pixels, as the decoders in this app always produced.
    convenience init(cgImage: CGImage, pixelSize: CGSize) {
        #if os(macOS)
        self.init(cgImage: cgImage, size: pixelSize)
        #else
        self.init(cgImage: cgImage, scale: 1, orientation: .up)
        #endif
    }

    static func load(contentsOf url: URL) -> PlatformImage? {
        #if os(macOS)
        NSImage(contentsOf: url)
        #else
        UIImage(contentsOfFile: url.path)
        #endif
    }

    var cgImageValue: CGImage? {
        #if os(macOS)
        cgImage(forProposedRect: nil, context: nil, hints: nil)
        #else
        cgImage
        #endif
    }

    func pngRepresentation() -> Data? {
        #if os(macOS)
        guard let tiff = tiffRepresentation, let rep = NSBitmapImageRep(data: tiff) else { return nil }
        return rep.representation(using: .png, properties: [:])
        #else
        pngData()
        #endif
    }
}
