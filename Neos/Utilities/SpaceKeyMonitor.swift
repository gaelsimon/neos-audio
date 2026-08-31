import AppKit

/// Space toggles playback. A menu key equivalent cannot: it is matched before the responder
/// chain, so it would swallow the Space the user typed into a text field.
@MainActor
final class SpaceKeyMonitor {
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
            // Only Sendable values cross into the actor; NSEvent itself stays on this side.
            let characters = event.charactersIgnoringModifiers
            let modifiers = event.modifierFlags.rawValue
            // The monitor is called on the main thread, where this class lives.
            let consumed = MainActor.assumeIsolated {
                self?.handleKey(
                    characters: characters,
                    modifiers: NSEvent.ModifierFlags(rawValue: modifiers),
                    firstResponder: NSApp.keyWindow?.firstResponder
                ) ?? false
            }
            return consumed ? nil : event
        }
    }

    func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
    }

    /// True when the keystroke was consumed as play/pause.
    func handle(_ event: NSEvent, firstResponder: NSResponder?) -> Bool {
        handleKey(
            characters: event.charactersIgnoringModifiers,
            modifiers: event.modifierFlags,
            firstResponder: firstResponder
        )
    }

    func handleKey(characters: String?, modifiers: NSEvent.ModifierFlags, firstResponder: NSResponder?) -> Bool {
        guard Self.isBareSpace(characters: characters, modifiers: modifiers),
              state.isConnected,
              !Self.isEditingText(firstResponder) else { return false }
        onToggle()
        return true
    }

    static func isBareSpace(characters: String?, modifiers: NSEvent.ModifierFlags) -> Bool {
        guard characters == " " else { return false }
        let relevant: NSEvent.ModifierFlags = [.command, .option, .control, .shift]
        return modifiers.isDisjoint(with: relevant)
    }

    /// A focused field hands editing to an NSTextView field editor, SwiftUI's `TextField` included.
    static func isEditingText(_ responder: NSResponder?) -> Bool {
        switch responder {
        case let text as NSText: text.isEditable
        case let field as NSTextField: field.currentEditor() != nil
        default: false
        }
    }

    deinit {
        if let monitor { NSEvent.removeMonitor(monitor) }
    }
}
