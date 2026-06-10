import SwiftUI

struct EmptyStateView: View {
    let icon: String
    let message: String

    var body: some View {
        VStack(spacing: DS.Spacing.sm) {
            Image(systemName: icon)
                .typography(.pageTitle)
                .foregroundStyle(DS.Colors.textTertiary)
            Text(message)
                .typography(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
