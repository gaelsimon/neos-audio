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
                .typography(.bodyPrimary, color: DS.Colors.textSecondary)

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

    // MARK: - Expired Service Link

    var expiredServiceLinkView: some View {
        let name = browseVM.selectedSource?.name ?? "This service"
        return ContentUnavailableView {
            Label("Service Sign-In Expired", systemImage: DS.Icons.signIn)
        } description: {
            Text("\(name) is no longer linked to your HEOS account. Sign in to it again in the HEOS app, under Music Sources.")
        } actions: {
            Button("Retry") { browseVM.retry() }
        }
    }

    // MARK: - Error View

    func errorView(_ error: String) -> some View {
        ContentUnavailableView {
            Label("Couldn't Load", systemImage: "exclamationmark.triangle")
        } description: {
            Text(error)
        } actions: {
            Button("Retry") { browseVM.retry() }
        }
    }
}
