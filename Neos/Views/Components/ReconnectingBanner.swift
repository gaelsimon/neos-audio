import SwiftUI

/// Thin top bar shown while a live session reconnects, in place of the full-screen splash.
struct ReconnectingBanner: View {
    let deviceName: String

    var body: some View {
        HStack(spacing: DS.Spacing.sm) {
            Spinner(size: 12, lineWidth: 2)
            Text("Reconnecting to \(deviceName)...")
                .typography(.secondary)
                .foregroundStyle(DS.Colors.textSecondary)
        }
        .padding(.horizontal, DS.Spacing.md)
        .padding(.vertical, DS.Spacing.sm)
        .background(DS.Colors.surfaceElevated, in: Capsule())
        .overlay(Capsule().stroke(DS.Colors.border, lineWidth: 1))
        .padding(.top, DS.Spacing.sm)
        .accessibilityIdentifier(AccessibilityID.Connection.reconnectingBanner)
    }
}
