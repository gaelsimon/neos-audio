import SwiftUI
import NeosDomain

extension BrowseContentView {
    // MARK: - Unavailable Service View

    func unavailableServiceView(_ source: MusicSource) -> some View {
        VStack(spacing: DS.Spacing.lg) {
            Spacer()
            ServiceBranding.serviceIcon(for: source, size: 80)
            Text(source.name)
                .typography(.pageTitle)
            Text("This service requires a HEOS account.")
                .typography(.bodyPrimary).foregroundStyle(DS.Colors.textSecondary)

            Button(action: { browseVM.navigateToSettings() }) {
                Text("Sign In")
                    .typography(.bodyEmphasis)
            }
            .buttonStyle(.bordered)
            .tint(DS.Colors.accent)
            .controlSize(.large)

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Sign In Prompt (browse error)

    func isAuthError(_ error: String) -> Bool {
        let lower = error.lowercased()
        return lower.contains("not logged in") || lower.contains("not signed in")
    }

    // MARK: - Error View

    func errorView(_ error: String) -> some View {
        ErrorStateView(
            message: error,
            actionLabel: "Retry",
            action: { browseVM.retry() }
        )
    }
}
