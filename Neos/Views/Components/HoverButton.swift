import SwiftUI

struct HoverButton<Label: View>: View {
    let action: () -> Void
    var accessibilityID: String?
    @ViewBuilder let label: (Bool) -> Label
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            label(isHovered)
                .hitTarget()
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .modifier(OptionalAccessibilityID(id: accessibilityID))
    }
}
