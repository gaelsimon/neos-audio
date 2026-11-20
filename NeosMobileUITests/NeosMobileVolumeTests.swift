import XCTest

/// The player's volume bar, on the demo speaker only: never drive a real speaker's volume from a UI test.
final class NeosMobileVolumeTests: MobileDemoTestCase {

    /// The full player's bar; on iPad the player bar's own one sits under the player.
    private var volume: XCUIElement {
        let sliders = app.sliders.matching(identifier: AccessibilityID.Player.volumeSlider)
        return (0..<sliders.count).lazy.map { sliders.element(boundBy: $0) }.first(where: \.isHittable) ?? sliders.firstMatch
    }

    private func level(_ slider: XCUIElement) -> Double {
        // Read as "45 %", with a space that depends on the language.
        let digits = (slider.value as? String ?? "").filter(\.isNumber)
        return Double(digits) ?? -1
    }

    private func point(_ slider: XCUIElement, at fraction: CGFloat) -> XCUICoordinate {
        slider.coordinate(withNormalizedOffset: CGVector(dx: fraction, dy: 0.5))
    }

    func testATouchOnTheBarLeavesTheVolume() {
        openPlayer()
        let slider = volume
        XCTAssertTrue(slider.waitForExistence(timeout: 5))
        let before = level(slider)

        point(slider, at: 0.95).tap()

        Thread.sleep(forTimeInterval: 1)
        XCTAssertEqual(level(slider), before, "A touch near the end moved the volume")
    }

    func testADragMovesTheVolumeByTheDistance() {
        openPlayer()
        let slider = volume
        XCTAssertTrue(slider.waitForExistence(timeout: 5))
        let before = level(slider)

        point(slider, at: 0.1).press(forDuration: 0.1, thenDragTo: point(slider, at: 0.3))

        XCTAssertEqual(level(slider) - before, 20, accuracy: 5, "From \(before) to \(level(slider))")
    }
}
