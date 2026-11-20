import XCTest
@testable import Neos

final class SearchCategoryNameTests: XCTestCase {
    func testASingularCategoryReadsInThePlural() {
        XCTAssertEqual(SearchCategoryName.plural("Track"), "Tracks")
    }

    func testAPluralCategoryStaysAsItIs() {
        XCTAssertEqual(SearchCategoryName.plural("Shows"), "Shows")
    }

    func testAnUnknownCategoryStaysAsItIs() {
        XCTAssertEqual(SearchCategoryName.plural("Live Radio"), "Live Radio")
    }
}
