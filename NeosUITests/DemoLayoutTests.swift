import XCTest

/// The player bar lies over the bottom of the window. Scrolled to its end, a page must still show its last line above it.
final class DemoLayoutTests: DemoTestCase {

    /// The bar pads its artwork evenly and reaches the window's bottom, which gives its top edge.
    private var playerTop: CGFloat {
        let window = app.windows.firstMatch.frame
        let artwork = app.descendants(matching: .any)[AccessibilityID.Player.albumArt].frame
        return artwork.minY - (window.maxY - artwork.maxY)
    }

    private func scrollToTheEnd() {
        let page = app.windows.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.4, dy: 0.5))
        for _ in 0..<8 {
            page.scroll(byDeltaX: 0, deltaY: -900)
        }
        Thread.sleep(forTimeInterval: 0.8)
    }

    /// A shelf may show the same card higher up the page, so the lowest one counts.
    private func lowestEdge(ofButtonsLabelled label: String) -> CGFloat? {
        app.buttons.matching(NSPredicate(format: "label == %@", label)).allElementsBoundByIndex.map(\.frame.maxY).max()
    }

    func testHomeEndsAboveThePlayer() throws {
        resetToHome()

        scrollToTheEnd()

        let lastCard = try XCTUnwrap(lowestEdge(ofButtonsLabelled: "Harbour Mouth, Coastline"), "Home should end on its last card")
        XCTAssertLessThanOrEqual(lastCard, playerTop, "The last card of Home should end above the player")
    }
}
