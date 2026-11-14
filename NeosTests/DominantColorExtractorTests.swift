import SwiftUI
import XCTest
@testable import Neos

final class DominantColorExtractorTests: XCTestCase {

    func testUniformArtworkYieldsOneColour() async {
        let image = TestImages.solid(red: 0.9, green: 0.4, blue: 0.1, size: 40)

        let colors = await DominantColorExtractor.extractColors(from: image)

        XCTAssertEqual(colors.count, 1)
    }

    func testBlackArtworkFallsBackToTheDefaults() async {
        let image = TestImages.solid(red: 0, green: 0, blue: 0, size: 40)

        let colors = await DominantColorExtractor.extractColors(from: image)

        XCTAssertEqual(colors, DominantColorExtractor.defaultColors)
    }
}
