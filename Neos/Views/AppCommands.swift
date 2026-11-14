import SwiftUI

struct AppCommands: Commands {
    let state: AppState
    let container: ViewModelContainer?

    private static let volumeStep = 5

    private var isLive: Bool { container != nil && state.isConnected }

    // ⌘ and the arrow keys move the caret while the search field is being edited.
    private var arrowShortcutsEnabled: Bool { isLive && !state.isSearchFieldFocused }

    var body: some Commands {
        CommandGroup(replacing: .appSettings) {
            Button("Settings…") { showSettings() }
                .keyboardShortcut(",", modifiers: .command)
                .disabled(!isLive)
        }

        CommandMenu("Playback") {
            // No shortcut: `SpaceKeyMonitor` owns Space so typing still works.
            Button(state.isPlaying ? "Pause" : "Play") {
                container?.playerVM.togglePlayPause()
            }
            .disabled(!isLive)

            Button("Next") { container?.playerVM.next() }
                .keyboardShortcut(.rightArrow, modifiers: .command)
                .disabled(!arrowShortcutsEnabled)

            Button("Previous") { container?.playerVM.previous() }
                .keyboardShortcut(.leftArrow, modifiers: .command)
                .disabled(!arrowShortcutsEnabled)

            Divider()

            Button("Volume Up") { container?.playerVM.stepVolume(by: Self.volumeStep) }
                .keyboardShortcut(.upArrow, modifiers: .command)
                .disabled(!arrowShortcutsEnabled)

            Button("Volume Down") { container?.playerVM.stepVolume(by: -Self.volumeStep) }
                .keyboardShortcut(.downArrow, modifiers: .command)
                .disabled(!arrowShortcutsEnabled)

            Divider()

            Button("Back") { container?.goBack() }
                .keyboardShortcut("[", modifiers: .command)
                .disabled(container?.canGoBack != true)

            Button("Forward") { container?.goForward() }
                .keyboardShortcut("]", modifiers: .command)
                .disabled(container?.canGoForward != true)

            Divider()

            Button("Search") { state.isSearchFieldFocused = true }
                .keyboardShortcut("f", modifiers: .command)
                .disabled(!isLive)

            Button(state.isQueuePanelOpen ? "Hide Queue" : "Show Queue") {
                state.isQueuePanelOpen.toggle()
            }
            .disabled(!isLive)

            Button(state.isNowPlayingCanvasOpen ? "Exit Full Screen Player" : "Full Screen Player") {
                state.isNowPlayingCanvasOpen.toggle()
            }
            .keyboardShortcut("f", modifiers: [.command, .shift])
            .disabled(!isLive)
        }
    }

    private func showSettings() {
        guard let browseVM = container?.browseVM, browseVM.currentDestination != .settings else { return }
        browseVM.navigateToSettings()
    }
}
