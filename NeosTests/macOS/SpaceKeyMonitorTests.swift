import XCTest
import SwiftUI
import AppKit
import NeosDomain
@testable import Neos

@MainActor
final class SpaceKeyMonitorTests: XCTestCase {

    private func makeMonitor(connectionState: ConnectionState = .connected)
        -> (SpaceKeyMonitor, AppState, Box) {
        let state = AppState()
        state.connectionState = connectionState
        let box = Box()
        let monitor = SpaceKeyMonitor(state: state) { box.toggles += 1 }
        return (monitor, state, box)
    }

    private func keyEvent(characters: String, modifiers: NSEvent.ModifierFlags = []) -> NSEvent {
        NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: modifiers,
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: characters,
            charactersIgnoringModifiers: characters,
            isARepeat: false,
            keyCode: 49
        )!
    }

    // MARK: - Consumption

    func testBareSpaceTogglesPlayback() {
        let (monitor, _, box) = makeMonitor()

        XCTAssertTrue(monitor.handle(keyEvent(characters: " "), firstResponder: nil))
        XCTAssertEqual(box.toggles, 1)
    }

    func testModifiedSpaceIsLeftToTheResponderChain() {
        let (monitor, _, box) = makeMonitor()

        XCTAssertFalse(monitor.handle(keyEvent(characters: " ", modifiers: .command), firstResponder: nil))
        XCTAssertEqual(box.toggles, 0)
    }

    func testOtherKeysAreIgnored() {
        let (monitor, _, box) = makeMonitor()

        XCTAssertFalse(monitor.handle(keyEvent(characters: "k"), firstResponder: nil))
        XCTAssertEqual(box.toggles, 0)
    }

    func testSpaceDoesNothingWhileDisconnected() {
        let (monitor, _, box) = makeMonitor(connectionState: .disconnected)

        XCTAssertFalse(monitor.handle(keyEvent(characters: " "), firstResponder: nil))
        XCTAssertEqual(box.toggles, 0)
    }

    // MARK: - Text Editing

    func testSpaceReachesAFieldEditor() {
        let (monitor, _, box) = makeMonitor()
        let editor = NSTextView()
        editor.isEditable = true

        XCTAssertFalse(monitor.handle(keyEvent(characters: " "), firstResponder: editor))
        XCTAssertEqual(box.toggles, 0)
    }

    func testSpaceIsHandledOverAReadOnlyTextView() {
        let (monitor, _, box) = makeMonitor()
        let label = NSTextView()
        label.isEditable = false

        XCTAssertTrue(monitor.handle(keyEvent(characters: " "), firstResponder: label))
        XCTAssertEqual(box.toggles, 1)
    }

    /// The regression this guards: typing a space into a station name must insert a space.
    func testSpaceReachesAFocusedSwiftUITextField() throws {
        let (monitor, _, box) = makeMonitor()
        let hosting = NSHostingView(rootView: TextFieldHarness())
        hosting.frame = NSRect(x: 0, y: 0, width: 300, height: 60)
        let window = NSWindow(contentRect: hosting.frame, styleMask: [.titled], backing: .buffered, defer: false)
        window.contentView = hosting
        window.makeKeyAndOrderFront(nil)
        hosting.layoutSubtreeIfNeeded()

        let field = try XCTUnwrap(findTextField(in: hosting), "no NSTextField in the hosted hierarchy")
        XCTAssertTrue(window.makeFirstResponder(field), "field refused first responder")

        // No keystroke yet: the editing notifications have not fired, but focus is already here.
        XCTAssertFalse(monitor.handle(keyEvent(characters: " "), firstResponder: window.firstResponder))
        XCTAssertEqual(box.toggles, 0)
    }

    private func findTextField(in view: NSView) -> NSTextField? {
        if let field = view as? NSTextField { return field }
        for subview in view.subviews {
            if let found = findTextField(in: subview) { return found }
        }
        return nil
    }
}

@MainActor
private final class Box {
    var toggles = 0
}

private struct TextFieldHarness: View {
    @State private var text = ""

    var body: some View {
        TextField("Station name", text: $text)
            .frame(width: 200)
    }
}
