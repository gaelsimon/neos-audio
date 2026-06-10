import SwiftUI

struct ErrorStateView: View {
    let message: String
    var icon: String = "exclamationmark.triangle"
    var actionLabel: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: DS.Spacing.sm) {
            Spacer()

            Image(systemName: icon)
                .typography(.pageTitle)
                .foregroundStyle(DS.Colors.textSecondary)

            Text(message)
                .typography(.secondary)
                .multilineTextAlignment(.center)

            if let actionLabel, let action {
                Button(actionLabel, action: action)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding()
    }
}
