import SwiftUI
import XCTest
@testable import Neos

final class PlatformImageTests: XCTestCase {

    func testPointSizeMatchesThePixelSize() {
        let image = TestImages.solid(red: 1, green: 0, blue: 0, size: 12)

        XCTAssertEqual(image.size, CGSize(width: 12, height: 12))
    }

    func testBitmapKeepsItsDimensions() throws {
        let cgImage = try XCTUnwrap(TestImages.solid(red: 0, green: 1, blue: 0, size: 6).cgImageValue)

        XCTAssertEqual(cgImage.width, 6)
        XCTAssertEqual(cgImage.height, 6)
    }

    func testPNGRoundTripsThroughAFile() throws {
        let png = try XCTUnwrap(TestImages.solid(red: 0, green: 0, blue: 1).pngRepresentation())
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).png")
        try png.write(to: file)
        defer { try? FileManager.default.removeItem(at: file) }

        let loaded = try XCTUnwrap(PlatformImage.load(contentsOf: file))

        XCTAssertEqual(loaded.size, CGSize(width: 8, height: 8))
    }

    func testMissingFileLoadsNothing() {
        let missing = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).png")

        XCTAssertNil(PlatformImage.load(contentsOf: missing))
    }

    func testWrapsIntoASwiftUIImage() {
        let image = Image(platformImage: TestImages.solid(red: 1, green: 1, blue: 0))

        XCTAssertNotNil(image)
    }
}
