import SwiftUI

/// Text that opens another page of the app, or plain text when there is nowhere to go.
struct CrossLink: View {
    enum Hover {
        case accent
        case underline
    }

    private let title: String
    private let typography: DS.Font
    private let hover: Hover
    private let action: (() -> Void)?
    @State private var isHovered = false

    init(_ title: String, typography: DS.Font = .secondary, hover: Hover = .accent, action: (() -> Void)?) {
        self.title = title
        self.typography = typography
        self.hover = hover
        self.action = action
    }

    var body: some View {
        if let action {
            Button(action: action) {
                label
                    .underline(hover == .underline && isHovered)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .pointingHandCursor(isHovered: $isHovered)
            .accessibilityAddTraits(.isLink)
        } else {
            label
        }
    }

    private var label: some View {
        Text(title)
            .typography(typography, color: hover == .accent && isHovered ? DS.Colors.accent : DS.Colors.textSecondary)
    }
}
