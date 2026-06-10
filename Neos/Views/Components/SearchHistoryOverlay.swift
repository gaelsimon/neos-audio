import SwiftUI

struct SearchHistoryOverlay: View {
    let queries: [String]
    let onSelect: (String) -> Void
    let onClear: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            header
            Rectangle()
                .fill(DS.Colors.border)
                .frame(height: 1)
            items
        }
        .background(DS.Colors.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.large))
        .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
        .accessibilityIdentifier(AccessibilityID.Search.historyOverlay)
        .accessibilityLabel("Recent searches")
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text("Recent Searches")
                .typography(.secondary)
                .foregroundStyle(DS.Colors.textSecondary)
            Spacer()
            HoverButton(action: onClear) { hovered in
                Text("Clear")
                    .typography(.badge)
                    .foregroundStyle(hovered ? .white : DS.Colors.textSecondary)
            }
            .accessibilityIdentifier(AccessibilityID.Search.clearHistoryButton)
            .accessibilityLabel("Clear search history")
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.Spacing.sm)
    }

    // MARK: - Items

    private var items: some View {
        ForEach(queries, id: \.self) { query in
            SearchHistoryRow(query: query) {
                onSelect(query)
            }
        }
    }
}

// MARK: - SearchHistoryRow

private struct SearchHistoryRow: View {
    let query: String
    let onTap: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: DS.Icons.historyUnfilled)
                    .font(DS.IconFont.body)
                    .foregroundStyle(DS.Colors.textTertiary)
                Text(query)
                    .typography(.bodyPrimary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer()
            }
            .padding(.horizontal, DS.Spacing.lg)
            .frame(height: 36)
            .contentShape(Rectangle())
            .background(
                isHovered
                    ? Color.white.opacity(0.06)
                    : Color.clear,
                in: RoundedRectangle(cornerRadius: DS.Radius.medium)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .accessibilityLabel("Search for \(query)")
        .accessibilityAddTraits(.isButton)
    }
}
