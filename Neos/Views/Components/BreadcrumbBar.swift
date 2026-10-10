import AppKit
import SwiftUI
import NeosDomain

/// Clickable path to the parents of the current level, which the page title names.
struct BreadcrumbBar: View {
    let stack: [BrowseTarget]
    let onSelect: (Int) -> Void

    private var levels: Int { stack.count - 1 }

    private enum Entry {
        case level(Int)
        case gap
    }

    /// A long path keeps its root and its last two levels; the middle collapses.
    private var shown: [Entry] {
        guard levels > 4 else { return (0..<levels).map(Entry.level) }
        return [.level(0), .gap, .level(levels - 2), .level(levels - 1)]
    }

    private var separator: some View {
        Image(systemName: DS.Icons.forward)
            .font(DS.IconFont.sm)
            .foregroundStyle(DS.Colors.textTertiary)
            .accessibilityHidden(true)
    }

    var body: some View {
        if levels > 0 {
            FadingHorizontalScroll {
                HStack(spacing: DS.Spacing.xs) {
                    ForEach(Array(shown.enumerated()), id: \.offset) { position, entry in
                        if position > 0 {
                            separator
                        }
                        switch entry {
                        case .gap:
                            Text("…")
                                .typography(.secondary)
                                .foregroundStyle(DS.Colors.textTertiary)
                        case .level(let index):
                            crumb(stack[index], at: index)
                        }
                    }
                }
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier(AccessibilityID.Browse.breadcrumb)
            }
        }
    }

    private func crumb(_ target: BrowseTarget, at index: Int) -> some View {
        BreadcrumbLink(title: target.name) { onSelect(index) }
            .accessibilityIdentifier(AccessibilityID.Browse.breadcrumbItem(index))
    }
}

// MARK: - Breadcrumb Link

/// Hover shows as an underline: a weight or colour change would reflow the row under the cursor.
private struct BreadcrumbLink: View {
    let title: String
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Text(title)
                .typography(.secondary)
                .lineLimit(1)
                .underline(isHovered)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .pointingHandCursor(isHovered: $isHovered)
    }
}
