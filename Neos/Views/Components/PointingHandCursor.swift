import SwiftUI
#if os(macOS)
import AppKit
#endif

extension View {
    /// For links only: buttons keep the arrow pointer.
    func pointingHandCursor(isHovered: Binding<Bool>) -> some View {
        onHover { hovering in
            isHovered.wrappedValue = hovering
            #if os(macOS)
            if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
            #endif
        }
        // A view removed under the pointer never gets its hover exit, so it pops the cursor itself.
        .onDisappear {
            guard isHovered.wrappedValue else { return }
            #if os(macOS)
            NSCursor.pop()
            #endif
            isHovered.wrappedValue = false
        }
    }
}
