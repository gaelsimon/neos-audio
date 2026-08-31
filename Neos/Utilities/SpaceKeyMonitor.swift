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
            // The monitor is called on the main thread, where this class lives.
            MainActor.assumeIsolated {
                guard let self, self.handle(event, firstResponder: NSApp.keyWindow?.firstResponder) else {
                    return event
                }
                return nil
            }
        }
    }

    func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
    }

    /// True when the keystroke was consumed as play/pause.
    func handle(_ event: NSEvent, firstResponder: NSResponder?) -> Bool {
        guard Self.isBareSpace(event),
              state.isConnected,
              !Self.isEditingText(firstResponder) else { return false }
        onToggle()
        return true
    }

    static func isBareSpace(_ event: NSEvent) -> Bool {
        guard event.charactersIgnoringModifiers == " " else { return false }
        let relevant: NSEvent.ModifierFlags = [.command, .option, .control, .shift]
        return event.modifierFlags.isDisjoint(with: relevant)
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
