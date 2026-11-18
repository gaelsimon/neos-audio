import SwiftUI

/// The queue panel as a card in its column, clear of the top bar, the player bar and the window's edge.
struct QueuePanelCard: View {
    let state: AppState
    let viewModel: QueuePanelViewModel
    let playerBarHeight: CGFloat
    let onClear: () -> Void

    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: DS.Radius.large) }

    var body: some View {
        QueuePanelView(state: state, viewModel: viewModel, onClose: { state.isQueuePanelOpen = false }, onClear: onClear)
            .clipShape(shape)
            .overlay { shape.strokeBorder(DS.Colors.glassEdge) }
            .padding(.horizontal, DS.Spacing.md)
            // Beside the full-screen player there is no top bar to stay clear of.
            .padding(.top, (state.isNowPlayingCanvasOpen ? 0 : DS.TopBar.height) + DS.Spacing.sm)
            .padding(.bottom, playerBarHeight + DS.Spacing.md)
            .background {
                QueuePanelGutter(state: state)
                    .ignoresSafeArea()
            }
            .ignoresSafeArea(edges: .top)
            .animation(.easeInOut(duration: 0.35), value: state.isNowPlayingCanvasOpen)
    }
}

/// What shows round the card: the page's colour, or the card's own beside the full-screen player, where a darker shade would cut the column off.
struct QueuePanelGutter: View {
    let state: AppState

    var body: some View {
        if state.isNowPlayingCanvasOpen {
            QueuePanelFill(state: state)
        } else {
            DS.Colors.background
        }
    }
}

/// Covers the hairline the system draws along the column's leading and top edges while the window is active.
struct QueuePanelColumnEdgeCover: View {
    let state: AppState
    let pageWidth: CGFloat

    var body: some View {
        GeometryReader { window in
            if pageWidth < window.size.width - 1 {
                ZStack(alignment: .topLeading) {
                    QueuePanelGutter(state: state).frame(width: 2)
                    QueuePanelGutter(state: state).frame(height: 1)
                }
                .padding(.leading, pageWidth - 1)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
