import SwiftUI
import NeosDomain

struct ConnectionStatusView: View {
    let state: AppState

    var body: some View {
        HStack(spacing: DS.Spacing.sm) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)

            Text(statusText)
                .typography(.secondary)

            if state.connectionState == .connecting || state.connectionState == .reconnecting {
                Spinner(size: 12, lineWidth: 1.5)
            }
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.Spacing.sm)
        .accessibilityIdentifier(AccessibilityID.Disconnected.statusIndicator)
    }

    private var statusColor: Color {
        switch state.connectionState {
        case .connected: .green
        case .connecting, .reconnecting: .orange
        case .disconnected: .red
        }
    }

    private var statusText: String {
        switch state.connectionState {
        case .connected:
            if let device = state.connectedDevice {
                return "Connected to \(device.friendlyName.isEmpty ? device.host : device.friendlyName)"
            }
            return "Connected"
        case .connecting: return "Connecting..."
        case .reconnecting: return "Reconnecting..."
        case .disconnected: return "Disconnected"
        }
    }
}
