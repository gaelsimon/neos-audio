import SwiftUI

/// The app's single treatment for text-level actions: Clear, See All, Ungroup, Sign Out.
struct TextActionButton: View {
    enum Role {
        case normal
        case destructive
    }

    let title: String
    var role: Role = .normal
    var isBusy = false
    var accessibilityID: String?
    let action: () -> Void

    var body: some View {
        HoverButton(action: action, accessibilityID: accessibilityID) { hovered in
            if isBusy {
                Spinner(size: 16, lineWidth: 2)
            } else {
                Text(title)
                    .typography(.secondary)
                    .foregroundStyle(color(hovered: hovered))
            }
        }
    }

    private func color(hovered: Bool) -> Color {
        switch role {
        case .normal:
            return hovered ? .white : DS.Colors.textSecondary
        case .destructive:
            return hovered ? DS.Colors.destructive : DS.Colors.destructive.opacity(0.75)
        }
    }
}
