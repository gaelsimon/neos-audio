import SwiftUI

struct TrackListHeader: View {
    var showArtist: Bool = true
    var showAlbum: Bool = true

    private var textColumnWeights: [CGFloat] {
        TrackListColumnWeights.textColumnWeights(showArtist: showArtist, showAlbum: showAlbum)
    }

    var body: some View {
        HStack(spacing: DS.Spacing.sm) {
            Text("#")
                .frame(width: DS.TrackList.numberWidth, alignment: .leading)

            TrackListWeightedColumnsLayout(weights: textColumnWeights, spacing: DS.Spacing.sm) {
                Text("TITLE")
                    .frame(maxWidth: .infinity, alignment: .leading)

                if showArtist {
                    Text("ARTIST")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if showAlbum {
                    Text("ALBUM")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .typography(.sidebarSection)
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.top, DS.Spacing.sm)
        .padding(.bottom, DS.Spacing.md)
    }
}

struct TrackListWeightedColumnsLayout: Layout {
    let weights: [CGFloat]
    let spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 0
        let columnWidths = makeColumnWidths(totalWidth: width)
        let height = subviews.enumerated().reduce(CGFloat.zero) { current, pair in
            let size = pair.element.sizeThatFits(ProposedViewSize(width: columnWidths[pair.offset], height: proposal.height))
            return max(current, size.height)
        }
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let columnWidths = makeColumnWidths(totalWidth: bounds.width)
        var x = bounds.minX
        for (index, subview) in subviews.enumerated() {
            let width = columnWidths[index]
            subview.place(at: CGPoint(x: x, y: bounds.midY), anchor: .leading, proposal: ProposedViewSize(width: width, height: bounds.height))
            x += width + spacing
        }
    }

    private func makeColumnWidths(totalWidth: CGFloat) -> [CGFloat] {
        let totalSpacing = spacing * CGFloat(max(0, weights.count - 1))
        let availableWidth = max(0, totalWidth - totalSpacing)
        let totalWeight = weights.reduce(0, +)
        return weights.map { availableWidth * ($0 / totalWeight) }
    }
}

enum TrackListColumnWeights {
    static func textColumnWeights(showArtist: Bool, showAlbum: Bool) -> [CGFloat] {
        var weights: [CGFloat] = [3]
        if showArtist { weights.append(2) }
        if showAlbum { weights.append(2) }
        return weights
    }
}
