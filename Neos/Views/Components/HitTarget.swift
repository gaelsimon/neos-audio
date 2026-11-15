import SwiftUI

extension View {
    /// The whole square takes the tap; a frame alone leaves it to the glyph drawn inside.
    func hitTarget(_ side: CGFloat = DS.HitTarget.button) -> some View {
        frame(minWidth: side, minHeight: side)
            .contentShape(Rectangle())
    }
}
