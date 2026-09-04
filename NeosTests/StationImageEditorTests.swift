import AppKit
import Foundation
import Testing
@testable import Neos

@Suite("StationImageEditor Tests")
struct StationImageEditorTests {

    private static let mid = "test-mid-station-image-editor"

    private var artworkDirectory: URL {
        URL.applicationSupportDirectory.appendingPathComponent("Neos/CustomArtwork", isDirectory: true)
    }

    private func makeImage(_ color: NSColor, size: CGFloat = 8) -> NSImage {
        let image = NSImage(size: CGSize(width: size, height: size))
        image.lockFocus()
        color.drawSwatch(in: NSRect(x: 0, y: 0, width: size, height: size))
        image.unlockFocus()
        return image
    }

    private func cleanUp(_ url: URL?) {
        guard let url else { return }
        try? FileManager.default.removeItem(at: url)
    }

    @Test func copyWritesAPNGIntoTheArtworkDirectory() throws {
        let written = StationImageEditor.copyToAppSupport(image: makeImage(.systemPink), forMID: Self.mid)
        defer { cleanUp(written) }

        let url = try #require(written)
        #expect(url.pathExtension == "png")
        #expect(url.deletingLastPathComponent().path == artworkDirectory.path)
        // Named `<media id hash>-<image bytes hash>`, so the same station can hold a new image.
        #expect(url.deletingPathExtension().lastPathComponent.split(separator: "-").map(\.count) == [64, 16])
        #expect(FileManager.default.fileExists(atPath: url.path))
        #expect(NSImage(contentsOf: url) != nil)
    }

    /// A replacement has to land on a new URL, or the image cache keeps serving the old bitmap.
    @Test func replacingTheImageYieldsADifferentFile() throws {
        let first = StationImageEditor.copyToAppSupport(image: makeImage(.systemPink), forMID: Self.mid)
        let second = StationImageEditor.copyToAppSupport(image: makeImage(.systemBlue), forMID: Self.mid)
        defer {
            cleanUp(first)
            cleanUp(second)
        }

        #expect(first != second)
        let url = try #require(second)
        #expect(FileManager.default.fileExists(atPath: url.path))
    }

    @Test func differentMediaIDsGetDifferentFiles() throws {
        let one = StationImageEditor.copyToAppSupport(image: makeImage(.systemPink), forMID: Self.mid + "-a")
        let two = StationImageEditor.copyToAppSupport(image: makeImage(.systemPink), forMID: Self.mid + "-b")
        defer {
            cleanUp(one)
            cleanUp(two)
        }
        #expect(one != two)
    }
}
