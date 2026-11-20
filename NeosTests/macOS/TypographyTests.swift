import XCTest
import SwiftUI
@testable import Neos

/// The Mac keeps its fixed sizes; only iPhone and iPad switch to text styles.
final class TypographyTests: XCTestCase {
    func testTheMacKeepsItsFixedSizes() {
        let expected: [DS.Font: SwiftUI.Font] = [
            .pageTitle: .system(size: 28, weight: .bold),
            .sectionHeader: .system(size: 18, weight: .semibold),
            .bodyPrimary: .system(size: 14),
            .bodyMedium: .system(size: 14, weight: .medium),
            .bodyEmphasis: .system(size: 14, weight: .semibold),
            .secondary: .system(size: 13),
            .secondaryEmphasis: .system(size: 13, weight: .semibold),
            .badge: .system(size: 13, weight: .semibold),
            .sidebarSection: .system(size: 12, weight: .medium),
            .footnote: .system(size: 11),
        ]
        for (style, font) in expected {
            XCTAssertEqual(style.font, font, "\(style)")
        }
    }

    func testCardsKeepTheSizesTheyHadBeforeTheirOwnStyles() {
        XCTAssertEqual(DS.Font.cardTitle.font, DS.Font.secondaryEmphasis.font)
        XCTAssertEqual(DS.Font.cardSubtitle.font, DS.Font.secondary.font)
    }
}
