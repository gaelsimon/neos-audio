import Foundation
import Testing
@testable import Neos

@Suite("StationImageEditor Tests")
struct StationImageEditorTests {

    private static let mid = "test-mid-station-image-editor"

    private var artworkDirectory: URL {
        URL.applicationSupportDirectory.appendingPathComponent("Neos/CustomArtwork", isDirectory: true)
    }

    private enum Swatch {
        case pink, blue
    }

    private func makeImage(_ swatch: Swatch) -> PlatformImage {
        switch swatch {
        case .pink: TestImages.solid(red: 1, green: 0.2, blue: 0.5)
        case .blue: TestImages.solid(red: 0, green: 0.4, blue: 1)
        }
    }

    private func cleanUp(_ url: URL?) {
        guard let url else { return }
        try? FileManager.default.removeItem(at: url)
    }

    @Test func copyWritesAPNGIntoTheArtworkDirectory() throws {
        let written = StationImageEditor.copyToAppSupport(image: makeImage(.pink), forMID: Self.mid)
        defer { cleanUp(written) }

        let url = try #require(written)
        #expect(url.pathExtension == "png")
        #expect(url.deletingLastPathComponent().path == artworkDirectory.path)
        // Named `<media id hash>-<image bytes hash>`, so the same station can hold a new image.
        #expect(url.deletingPathExtension().lastPathComponent.split(separator: "-").map(\.count) == [64, 16])
        #expect(FileManager.default.fileExists(atPath: url.path))
        #expect(PlatformImage.load(contentsOf: url) != nil)
    }

    /// A replacement has to land on a new URL, or the image cache keeps serving the old bitmap.
    @Test func replacingTheImageYieldsADifferentFile() throws {
        let first = StationImageEditor.copyToAppSupport(image: makeImage(.pink), forMID: Self.mid)
        let second = StationImageEditor.copyToAppSupport(image: makeImage(.blue), forMID: Self.mid)
        defer {
            cleanUp(first)
            cleanUp(second)
        }

        #expect(first != second)
        let url = try #require(second)
        #expect(FileManager.default.fileExists(atPath: url.path))
    }

    @Test func differentMediaIDsGetDifferentFiles() throws {
        let one = StationImageEditor.copyToAppSupport(image: makeImage(.pink), forMID: Self.mid + "-a")
        let two = StationImageEditor.copyToAppSupport(image: makeImage(.pink), forMID: Self.mid + "-b")
        defer {
            cleanUp(one)
            cleanUp(two)
        }
        #expect(one != two)
    }
}
