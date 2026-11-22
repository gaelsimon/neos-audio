import SwiftUI

/// A page shown as a sheet: its title in the bar and a Done button.
struct DoneSheet<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            content
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }
                    }
                }
        }
        .cappedTextSize()
    }
}

/// The speakers and their groups, opened from the toolbar, the mini player or the player.
struct SpeakersSheet: View {
    let state: AppState
    let container: ViewModelContainer

    var body: some View {
        DoneSheet(title: "Speakers") {
            AmpSettingsView(state: state, speakerVM: container.speakerVM, groupVM: container.groupVM)
        }
        .toastOnTop(state)
    }
}
