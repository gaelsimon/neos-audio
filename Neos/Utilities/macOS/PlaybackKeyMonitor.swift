import AppKit

/// Space toggles playback, and ⌘ with an arrow reaches the field being edited before the Playback menu takes it.
@MainActor
final class PlaybackKeyMonitor {
    private let state: AppState
    private let onToggle: () -> Void
    nonisolated(unsafe) private var monitor: Any?

    init(state: AppState, onToggle: @escaping () -> Void) {
        self.state = state
        self.onToggle = onToggle
    }

    func start() {
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            // The monitor is called on the main thread, where this class lives.
            nonisolated(unsafe) let event = event
            let consumed = MainActor.assumeIsolated {
                self?.handle(event, firstResponder: NSApp.keyWindow?.firstResponder) ?? false
            }
            return consumed ? nil : event
        }
    }

    func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
    }

    /// True when the keystroke was consumed here.
    func handle(_ event: NSEvent, firstResponder: NSResponder?) -> Bool {
        let characters = event.charactersIgnoringModifiers
        let modifiers = event.modifierFlags
        if Self.isCommandArrow(characters: characters, modifiers: modifiers) {
            guard let editor = Self.textEditor(of: firstResponder) else { return false }
            editor.keyDown(with: event)
            return true
        }
        guard Self.isBareSpace(characters: characters, modifiers: modifiers),
              state.isConnected,
              Self.textEditor(of: firstResponder) == nil else { return false }
        onToggle()
        return true
    }

    static func isBareSpace(characters: String?, modifiers: NSEvent.ModifierFlags) -> Bool {
        guard characters == " " else { return false }
        return modifiers.isDisjoint(with: relevantModifiers)
    }

    static func isCommandArrow(characters: String?, modifiers: NSEvent.ModifierFlags) -> Bool {
        guard let key = characters?.utf16.first, arrowKeys.contains(Int(key)) else { return false }
        return modifiers.intersection(relevantModifiers) == .command
    }

    /// A focused field hands editing to an NSTextView field editor, SwiftUI's `TextField` included.
    static func textEditor(of responder: NSResponder?) -> NSResponder? {
        switch responder {
        case let text as NSText: text.isEditable ? text : nil
        case let field as NSTextField: field.currentEditor()
        default: nil
        }
    }

    private static let relevantModifiers: NSEvent.ModifierFlags = [.command, .option, .control, .shift]
    private static let arrowKeys = [NSLeftArrowFunctionKey, NSRightArrowFunctionKey, NSUpArrowFunctionKey, NSDownArrowFunctionKey]

    deinit {
        if let monitor { NSEvent.removeMonitor(monitor) }
    }
}
