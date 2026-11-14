import SwiftUI

struct HoverButton<Label: View>: View {
    let action: () -> Void
    var accessibilityID: String?
    @ViewBuilder let label: (Bool) -> Label
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            label(isHovered)
                .frame(minWidth: 36, minHeight: 36)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .modifier(OptionalAccessibilityID(id: accessibilityID))
    }
}

private struct OptionalAccessibilityID: ViewModifier {
    let id: String?

    func body(content: Content) -> some View {
        if let id {
            content.accessibilityIdentifier(id)
        } else {
            content
        }
    }
}
