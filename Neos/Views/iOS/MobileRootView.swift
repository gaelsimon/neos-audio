import SwiftUI

extension EnvironmentValues {
    /// An iPad window wide enough for the player bar, the queue inspector and a search field under the title.
    @Entry var showsPadChrome = false
}

/// The device, not the window: rotating or resizing must not swap the player's presentation or move the
/// mini player under the user.
enum DeviceIdiom {
    static var isPad: Bool { UIDevice.current.userInterfaceIdiom == .pad }
}

/// The iPhone and iPad app: discovery until a speaker answers, then the tabs.
struct MobileRootView: View {
    let state: AppState
    let container: ViewModelContainer
    @State private var showConnectedSplash = false
    @Environment(\.horizontalSizeClass) private var sizeClass

    private var isPad: Bool { DeviceIdiom.isPad }

    var body: some View {
        ConnectionGate(state: state, speakerVM: container.speakerVM, isHoldingSplash: $showConnectedSplash) {
            MobileTabView(state: state, container: container)
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
        // Rows and the mini player have fixed heights that the accessibility sizes would overflow.
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    }

    /// The player slides up as a sheet on iPhone and takes the whole screen on iPad.
    private func playerPresentation(fullScreen: Bool) -> Binding<Bool> {
        Binding(
            get: { state.isNowPlayingCanvasOpen && isPad == fullScreen },
            set: { state.isNowPlayingCanvasOpen = $0 }
        )
    }
}
