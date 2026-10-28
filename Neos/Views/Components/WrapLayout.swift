import SwiftUI

/// Lays children out left to right and starts a new row when the next one would overflow.
struct WrapLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        return place(subviews, in: width).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for (subview, offset) in zip(subviews, place(subviews, in: bounds.width).offsets) {
            subview.place(at: CGPoint(x: bounds.minX + offset.x, y: bounds.minY + offset.y), proposal: .unspecified)
        }
    }

    private func place(_ subviews: Subviews, in width: CGFloat) -> (offsets: [CGPoint], size: CGSize) {
        var offsets: [CGPoint] = []
        var cursor = CGPoint.zero
        var rowHeight: CGFloat = 0
        var usedWidth: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if cursor.x > 0, cursor.x + size.width > width {
                cursor = CGPoint(x: 0, y: cursor.y + rowHeight + spacing)
                rowHeight = 0
            }
            offsets.append(cursor)
            rowHeight = max(rowHeight, size.height)
            cursor.x += size.width + spacing
            usedWidth = max(usedWidth, cursor.x - spacing)
        }
        return (offsets, CGSize(width: usedWidth, height: cursor.y + rowHeight))
    }
}
