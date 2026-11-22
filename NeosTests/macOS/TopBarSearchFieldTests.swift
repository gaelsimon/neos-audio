import AppKit
import SwiftUI
import XCTest
@testable import Neos

@MainActor
final class TopBarSearchFieldTests: XCTestCase {
    private var window: NSWindow?
    private var clears = 0
    private var submits = 0

    override func tearDown() async throws {
        await MainActor.run {
            window?.close()
            window = nil
        }
    }

    private func focusedField(text: String = "The Velvet Hours") throws -> FocusTrackingSearchField {
        let size = CGSize(width: 260, height: 32)
        let host = NSHostingView(
            rootView: TopBarSearchField(
                text: .constant(text),
                isFocused: .constant(true),
                onClear: { [weak self] in self?.clears += 1 },
                onSubmit: { [weak self] in self?.submits += 1 }
            )
            .frame(width: size.width, height: size.height)
        )
        host.frame = CGRect(origin: .zero, size: size)
        let window = NSWindow(contentRect: host.frame, styleMask: [], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = host
        host.layoutSubtreeIfNeeded()
        self.window = window

        let field = try XCTUnwrap(host.firstDescendant(ofType: FocusTrackingSearchField.self))
        window.makeFirstResponder(field)
        return field
    }

    private func buttonCentres(of field: NSSearchField) throws -> (magnifier: CGPoint, clear: CGPoint) {
        let cell = try XCTUnwrap(field.cell as? NSSearchFieldCell)
        let magnifier = cell.searchButtonRect(forBounds: field.bounds)
        let clear = cell.cancelButtonRect(forBounds: field.bounds)
        return (CGPoint(x: magnifier.midX, y: magnifier.midY), CGPoint(x: clear.midX, y: clear.midY))
    }

    private func editorFrame(in field: NSSearchField) throws -> CGRect {
        let editor = try XCTUnwrap(field.currentEditor())
        return editor.convert(editor.visibleRect, to: field)
    }

    func testTheEditorLeavesTheMagnifierUncovered() throws {
        let field = try focusedField()

        let editor = try editorFrame(in: field)

        XCTAssertFalse(editor.contains(try buttonCentres(of: field).magnifier), "editor at \(editor)")
    }

    func testTheEditorLeavesTheClearButtonUncovered() throws {
        let field = try focusedField()

        let editor = try editorFrame(in: field)

        XCTAssertFalse(editor.contains(try buttonCentres(of: field).clear), "editor at \(editor)")
    }

    func testTheClearButtonTakesItsClickWhileEditing() throws {
        let field = try focusedField()
        let host = try XCTUnwrap(window?.contentView)

        let hit = host.hitTest(field.convert(try buttonCentres(of: field).clear, to: host.superview))

        XCTAssertTrue(hit === field, "hit \(String(describing: hit))")
    }

    func testTheEditorStaysOffTheClearButtonAfterTheTextIsReplaced() throws {
        let field = try focusedField()

        field.stringValue = "Midnight Opera"

        XCTAssertFalse(try editorFrame(in: field).contains(try buttonCentres(of: field).clear))
    }

    func testALongQueryStaysOffTheClearButton() throws {
        let field = try focusedField(text: String(repeating: "The Velvet Hours ", count: 8))

        XCTAssertFalse(try editorFrame(in: field).contains(try buttonCentres(of: field).clear))
    }

    func testTheClearButtonRunsTheClearAction() throws {
        let field = try focusedField()
        let button = try XCTUnwrap((field.cell as? NSSearchFieldCell)?.cancelButtonCell)

        NSApp.sendAction(try XCTUnwrap(button.action), to: button.target, from: field)

        XCTAssertEqual(clears, 1)
    }

    func testAClickKeepsTheFocusWhenTheBarRedrawsBeforeTheFieldReportsIt() throws {
        let model = FieldModel()
        let host = NSHostingView(rootView: FieldHarness(model: model))
        host.frame = CGRect(x: 0, y: 0, width: 260, height: 32)
        let window = NSWindow(contentRect: host.frame, styleMask: [], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = host
        host.layoutSubtreeIfNeeded()
        self.window = window
        let field = try XCTUnwrap(host.firstDescendant(ofType: FocusTrackingSearchField.self))

        window.makeFirstResponder(field)
        model.text = "V"
        host.layoutSubtreeIfNeeded()

        XCTAssertNotNil(field.currentEditor(), "The field should keep the focus a click gave it")
    }

    func testReturnSubmitsTheQuery() throws {
        let field = try focusedField()
        let editor = try XCTUnwrap(field.currentEditor() as? NSTextView)

        editor.doCommand(by: #selector(NSResponder.insertNewline(_:)))

        XCTAssertEqual(submits, 1)
    }
}

@Observable
private final class FieldModel {
    var text = ""
    var isFocused = false
}

private struct FieldHarness: View {
    @Bindable var model: FieldModel

    var body: some View {
        TopBarSearchField(text: $model.text, isFocused: $model.isFocused, onClear: {}, onSubmit: {})
            .frame(width: 260, height: 32)
    }
}

private extension NSView {
    func firstDescendant<View: NSView>(ofType type: View.Type) -> View? {
        for subview in subviews {
            if let match = subview as? View ?? subview.firstDescendant(ofType: type) { return match }
        }
        return nil
    }
}
