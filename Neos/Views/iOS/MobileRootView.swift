import SwiftUI

extension EnvironmentValues {
    /// An iPad window wide enough for the player bar, the queue inspector and a search field under the title.
    @Entry var showsPadChrome = false
}

/// The iPhone and iPad app: discovery until a speaker answers, then the tabs.
struct MobileRootView: View {
    let state: AppState
    let container: ViewModelContainer
    @State private var showConnectedSplash = false
    @State private var volumeButtons = VolumeButtons(system: PhoneVolume())
    @State private var volumeButtonPresses = 0
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.scenePhase) private var scenePhase

    private var isPad: Bool { DeviceIdiom.isPad }

    /// As in the HEOS app, the phone's volume buttons are the speaker's while the app is in front.
    private var takesVolumeButtons: Bool { scenePhase == .active && state.isConnected }

    var body: some View {
        ConnectionGate(state: state, speakerVM: container.speakerVM, isHoldingSplash: $showConnectedSplash) {
            MobileTabView(state: state, container: container)
        }
        .overlay(alignment: .top) {
            VolumeButtonIndicator(state: state, presses: volumeButtonPresses)
        }
        .onChange(of: takesVolumeButtons, initial: true) { _, takes in
            if takes {
                volumeButtons.start { presses in
                    container.playerVM.pressVolumeButtons(presses)
                    volumeButtonPresses += 1
                }
            } else {
                volumeButtons.stop()
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: playerPresentation(fullScreen: false)) {
            MobileNowPlayingView(state: state, container: container)
                .presentationDragIndicator(.visible)
        }
        .fullScreenCover(isPresented: playerPresentation(fullScreen: true)) {
            MobileNowPlayingView(state: state, container: container)
        }
        // Outermost, so the presented player and sheets inherit them too.
        .environment(\.pageMargin, sizeClass == .regular ? DS.Layout.regularPageMargin : DS.Layout.pageMargin)
        .environment(\.showsPadChrome, isPad && sizeClass == .regular)
        .cappedTextSize()
    }

    /// The player slides up as a sheet on iPhone and takes the whole screen on iPad.
    private func playerPresentation(fullScreen: Bool) -> Binding<Bool> {
        Binding(
            get: { state.isNowPlayingCanvasOpen && isPad == fullScreen },
            set: { state.isNowPlayingCanvasOpen = $0 }
        )
    }
}
