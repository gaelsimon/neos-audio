import SwiftUI
import NeosDomain

struct DiscoveredDeviceCard: View {
    let device: DiscoveredDevice
    /// Resolved by AppState so a known stereo pair shows its room name, not the leader's.
    var name: String?
    let onConnect: () -> Void
    @State private var isHovered = false

    private var displayName: String { name ?? device.friendlyName }

    var body: some View {
        Button(action: onConnect) {
            HStack(spacing: DS.Spacing.md) {
                Image(systemName: DS.Icons.speaker)
                    .typography(.pageTitle)
                    .foregroundStyle(DS.Colors.textSecondary)

                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    Text(displayName.isEmpty || displayName == device.host
                         ? device.host
                         : displayName)
                        .typography(.secondaryEmphasis)
                    if !displayName.isEmpty, displayName != device.host {
                        Text(device.host)
                            .typography(.secondary)
                            .foregroundStyle(DS.Colors.textTertiary)
                    }
                }

                Spacer()

                Image(systemName: DS.Icons.navigate)
                    .foregroundStyle(DS.Colors.accent)
            }
            .padding(DS.Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.medium)
                    .fill(isHovered ? DS.Colors.surfaceElevated : Color(white: 0.15))
                    .opacity(0.5)
            )
            .contentShape(Rectangle())
            .onHover { isHovered = $0 }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(AccessibilityID.Discovery.deviceCard(device.host))
    }
}
