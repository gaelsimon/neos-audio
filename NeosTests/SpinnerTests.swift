import XCTest
#if os(macOS)
import AppKit
#else
import UIKit
#endif
@testable import Neos

@MainActor
final class SpinnerTests: XCTestCase {

    private func makeSpinner() -> SpinnerView {
        SpinnerView(frame: CGRect(x: 0, y: 0, width: 20, height: 20))
    }

    #if os(macOS)
    private func makeWindow() -> NSWindow {
        let window = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 40, height: 40), styleMask: [], backing: .buffered, defer: true)
        window.isReleasedWhenClosed = false
        return window
    }

    private func put(_ spinner: SpinnerView, in window: NSWindow) {
        window.contentView?.addSubview(spinner)
    }

    private func layOut(_ spinner: SpinnerView) {
        spinner.layout()
    }
    #else
    private func makeWindow() -> UIWindow {
        UIWindow(frame: CGRect(x: 0, y: 0, width: 40, height: 40))
    }

    private func put(_ spinner: SpinnerView, in window: UIWindow) {
        window.addSubview(spinner)
    }

    private func layOut(_ spinner: SpinnerView) {
        spinner.layoutIfNeeded()
    }
    #endif

    func testTheArcTurnsInCoreAnimationOnceInAWindow() {
        let window = makeWindow()
        let spinner = makeSpinner()

        put(spinner, in: window)

        XCTAssertNotNil(spinner.arc.animation(forKey: SpinnerView.rotationKey))
    }

    func testNothingTurnsOutsideAWindow() {
        let spinner = makeSpinner()

        XCTAssertNil(spinner.arc.animation(forKey: SpinnerView.rotationKey))
    }

    func testMovingBetweenWindowsKeepsASingleRotation() {
        let window = makeWindow()
        let spinner = makeSpinner()
        put(spinner, in: window)

        spinner.removeFromSuperview()
        put(spinner, in: window)

        XCTAssertEqual(spinner.arc.animationKeys(), [SpinnerView.rotationKey])
    }

    func testTheRotationOutlivesTheAppGoingToTheBackground() {
        let window = makeWindow()
        let spinner = makeSpinner()

        put(spinner, in: window)

        XCTAssertEqual(spinner.arc.animation(forKey: SpinnerView.rotationKey)?.isRemovedOnCompletion, false)
    }

    func testTheStrokeSitsInsideTheBounds() {
        let spinner = makeSpinner()
        spinner.lineWidth = 2

        layOut(spinner)

        XCTAssertEqual(spinner.arc.path?.boundingBox, CGRect(x: 1, y: 1, width: 18, height: 18))
    }

    func testTheColorReachesTheStroke() {
        let spinner = SpinnerView(frame: .zero)
        let white = CGColor(gray: 1, alpha: 1)

        spinner.color = white

        XCTAssertEqual(spinner.arc.strokeColor, white)
    }
}
