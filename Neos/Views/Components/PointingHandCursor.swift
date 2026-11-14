import AppKit
import SwiftUI

extension View {
    /// For links only: buttons keep the arrow pointer.
    func pointingHandCursor(isHovered: Binding<Bool>) -> some View {
        onHover { hovering in
            isHovered.wrappedValue = hovering
            if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
        }
        // A view removed under the pointer never gets its hover exit, so it pops the cursor itself.
        .onDisappear {
            guard isHovered.wrappedValue else { return }
            NSCursor.pop()
            isHovered.wrappedValue = false
        }
    }
}
