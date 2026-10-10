import SwiftUI

struct LocalServerSettingsView: View {
    let servers: [LocalServersViewModel.Server]
    let preferences: LocalServerPreferences

    private let columnWidth: CGFloat = 56

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack(spacing: DS.Spacing.md) {
                Spacer()
                Text("Show")
                    .typography(.footnote)
                    .frame(width: columnWidth)
                Text("Search")
                    .typography(.footnote)
                    .frame(width: columnWidth)
            }
            ForEach(servers) { server in
                row(server)
            }
        }
    }

    private func row(_ server: LocalServersViewModel.Server) -> some View {
        HStack(spacing: DS.Spacing.md) {
            Text(server.name)
                .typography(.bodyPrimary)
                .lineLimit(1)
            if !server.isOnline {
                Text("Offline")
                    .typography(.footnote)
            }
            Spacer()
            Toggle("Show \(server.name)", isOn: Binding(
                get: { preferences.isShown(server.name) },
                set: { preferences.setShown($0, for: server.name) }
            ))
            .frame(width: columnWidth)
            .accessibilityIdentifier(AccessibilityID.Settings.localServerShow(server.name))
            Toggle("Search \(server.name)", isOn: Binding(
                get: { preferences.isSearchable(server.name) },
                set: { preferences.setSearchable($0, for: server.name) }
            ))
            .disabled(!preferences.isShown(server.name))
            .frame(width: columnWidth)
            .accessibilityIdentifier(AccessibilityID.Settings.localServerSearch(server.name))
        }
        .toggleStyle(.checkbox)
        .labelsHidden()
        .padding(.vertical, DS.Spacing.xs)
    }
}
