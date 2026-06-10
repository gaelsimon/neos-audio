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
    }
}
