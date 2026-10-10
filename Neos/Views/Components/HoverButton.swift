import AppKit
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
        .pointingHandCursor(isHovered: $isHovered)
        .modifier(OptionalAccessibilityID(id: accessibilityID))
    }
}

extension View {
    // A view removed under the pointer never gets its hover exit, so it pops the cursor itself.
    func pointingHandCursor(isHovered: Binding<Bool>) -> some View {
        onHover { hovering in
            isHovered.wrappedValue = hovering
            if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
        }
        .onDisappear {
            guard isHovered.wrappedValue else { return }
            NSCursor.pop()
            isHovered.wrappedValue = false
        }
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
