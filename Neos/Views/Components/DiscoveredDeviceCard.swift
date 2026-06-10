import SwiftUI
import NeosDomain

struct DiscoveredDeviceCard: View {
    let device: DiscoveredDevice
    let onConnect: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: onConnect) {
            HStack(spacing: DS.Spacing.md) {
                Image(systemName: DS.Icons.speaker)
                    .typography(.pageTitle)
                    .foregroundStyle(DS.Colors.textSecondary)

                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    Text(device.friendlyName.isEmpty || device.friendlyName == device.host
                         ? device.host
                         : device.friendlyName)
                        .typography(.secondaryEmphasis)
                    if !device.friendlyName.isEmpty, device.friendlyName != device.host {
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
