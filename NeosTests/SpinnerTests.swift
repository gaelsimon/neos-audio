import XCTest
@testable import Neos

@MainActor
final class SpinnerTests: XCTestCase {

    private func spinnerInWindow() -> (SpinnerNSView, NSWindow) {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 40, height: 40), styleMask: [], backing: .buffered, defer: true)
        window.isReleasedWhenClosed = false
        let spinner = SpinnerNSView(frame: NSRect(x: 0, y: 0, width: 20, height: 20))
        window.contentView?.addSubview(spinner)
        return (spinner, window)
    }

    func testTheArcTurnsInCoreAnimationOnceInAWindow() {
        let (spinner, window) = spinnerInWindow()
        defer { window.close() }

        XCTAssertNotNil(spinner.arc.animation(forKey: SpinnerNSView.rotationKey))
    }

    func testNothingTurnsOutsideAWindow() {
        let spinner = SpinnerNSView(frame: NSRect(x: 0, y: 0, width: 20, height: 20))

        XCTAssertNil(spinner.arc.animation(forKey: SpinnerNSView.rotationKey))
    }

    func testMovingBetweenWindowsKeepsASingleRotation() {
        let (spinner, window) = spinnerInWindow()
        defer { window.close() }

        spinner.removeFromSuperview()
        window.contentView?.addSubview(spinner)

        XCTAssertEqual(spinner.arc.animationKeys(), [SpinnerNSView.rotationKey])
    }

    func testTheStrokeSitsInsideTheBounds() {
        let spinner = SpinnerNSView(frame: NSRect(x: 0, y: 0, width: 20, height: 20))
        spinner.lineWidth = 2

        spinner.layout()

        XCTAssertEqual(spinner.arc.path?.boundingBox, NSRect(x: 1, y: 1, width: 18, height: 18))
    }

    func testTheColorReachesTheStroke() {
        let spinner = SpinnerNSView(frame: .zero)

        spinner.color = .white

        XCTAssertEqual(spinner.arc.strokeColor, NSColor.white.cgColor)
    }
}
