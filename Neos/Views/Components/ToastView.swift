import SwiftUI

struct ToastMessage: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let icon: String
    let style: Style

    enum Style: Equatable {
        case success
        case error
        case info
    }

    var foregroundColor: Color {
        switch style {
        case .success: .green
        case .error: .red
        case .info: .secondary
        }
    }
}

struct ToastView: View {
    let message: ToastMessage

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: message.icon)
                .foregroundStyle(message.foregroundColor)
            Text(message.text)
                .typography(.bodyPrimary)
                .lineLimit(1)
                .accessibilityIdentifier(AccessibilityID.Toast.message)
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.Spacing.sm)
        .background(.regularMaterial, in: Capsule())
        .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
        .accessibilityIdentifier(AccessibilityID.Toast.view)
        .onAppear { AccessibilityNotification.Announcement(message.text).post() }
    }
}

/// The toast of the moment, sliding in from the bottom.
struct ToastOverlay: View {
    let state: AppState

    var body: some View {
        ZStack {
            if let toast = state.toast {
                ToastView(message: toast)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.bottom, DS.Spacing.lg)
                    .id(toast.id)
            }
        }
        .animation(.easeInOut(duration: DS.Animation.standard), value: state.toast)
    }
}

extension EnvironmentValues {
    /// How many sheets deep a view sits: the toast shows on the deepest screen that can show it.
    @Entry var toastDepth = 0
}

/// The toast on a page or a sheet that another sheet may cover.
struct FrontmostToast: View {
    let state: AppState
    let depth: Int
    @State private var id = UUID()

    var body: some View {
        ZStack {
            if state.toastHosts.isFrontmost(depth: depth) {
                ToastOverlay(state: state)
            }
        }
        .onAppear { state.toastHosts.enter(id, depth: depth) }
        .onDisappear { state.toastHosts.leave(id) }
    }
}

/// A sheet's own place for the toast, one level deeper than whatever presents it.
private struct ToastOnTop: ViewModifier {
    let state: AppState
    @Environment(\.toastDepth) private var depth

    func body(content: Content) -> some View {
        content
            .environment(\.toastDepth, depth + 1)
            .overlay(alignment: .bottom) { FrontmostToast(state: state, depth: depth + 1) }
    }
}

extension View {
    @ViewBuilder
    func toastOnTop(_ state: AppState) -> some View {
        #if os(iOS)
        modifier(ToastOnTop(state: state))
        #else
        // A Mac sheet leaves the window's own toast in sight.
        self
        #endif
    }
}
