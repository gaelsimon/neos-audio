import AppKit
import SwiftUI
import NeosDomain

/// Clickable path back up the browse stack.
struct BreadcrumbBar: View {
    let stack: [BrowseTarget]
    let onSelect: (Int) -> Void

    var body: some View {
        if stack.count > 1 {
            FadingHorizontalScroll {
                HStack(spacing: DS.Spacing.xs) {
                    ForEach(Array(stack.enumerated()), id: \.offset) { index, target in
                        if index > 0 {
                            Image(systemName: DS.Icons.forward)
                                .font(DS.IconFont.sm)
                                .foregroundStyle(DS.Colors.textTertiary)
                                .accessibilityHidden(true)
                        }
                        crumb(target, at: index)
                    }
                }
                .padding(.horizontal, DS.Spacing.xxl)
                .padding(.vertical, DS.Spacing.sm)
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier(AccessibilityID.Browse.breadcrumb)
            }
        }
    }

    @ViewBuilder
    private func crumb(_ target: BrowseTarget, at index: Int) -> some View {
        if index == stack.count - 1 {
            Text(target.name)
                .typography(.secondaryEmphasis)
                .lineLimit(1)
                .accessibilityIdentifier(AccessibilityID.Browse.breadcrumbItem(index))
        } else {
            BreadcrumbLink(title: target.name) { onSelect(index) }
                .accessibilityIdentifier(AccessibilityID.Browse.breadcrumbItem(index))
        }
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
        .onHover { hovering in
            isHovered = hovering
            if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
        }
    }
}
