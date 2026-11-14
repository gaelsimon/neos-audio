import SwiftUI

struct HoverButton<Label: View>: View {
    let action: () -> Void
    var accessibilityID: String?
    @ViewBuilder let label: (Bool) -> Label
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            label(isHovered)
                .frame(minWidth: DS.HitTarget.button, minHeight: DS.HitTarget.button)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .modifier(OptionalAccessibilityID(id: accessibilityID))
    }
}
