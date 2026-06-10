import SwiftUI
import NeosDomain

struct InputSelectorGrid: View {
    let items: [BrowseItem]
    let activeInputMID: String?
    let onSelect: (BrowseItem) -> Void

    private let columns = [GridItem(.adaptive(minimum: 100), spacing: DS.Spacing.lg)]

    var body: some View {
        if items.isEmpty {
            emptyState
        } else {
            LazyVGrid(columns: columns, spacing: DS.Spacing.lg) {
                ForEach(items, id: \.id) { item in
                    inputCard(item)
                }
            }
            .padding(.horizontal, DS.Spacing.xxl)
            .padding(.top, DS.Spacing.xl)
            .accessibilityIdentifier(AccessibilityID.InputSelector.grid)
        }
    }

    // MARK: - Input Card

    private func inputCard(_ item: BrowseItem) -> some View {
        let isActive = isActiveInput(item)
        let icon = item.isSubSource ? "hifispeaker.fill" : ServiceBranding.sfSymbolIcon(forItemName: item.name)
        let displayName = Self.stripPlayerPrefix(item.name)
        return InputCardButton(
            icon: icon,
            name: displayName,
            isActive: isActive,
            accessibilityID: AccessibilityID.InputSelector.card(item.name)
        ) {
            onSelect(item)
        }
    }

    /// Strips the player name prefix (e.g. "Marantz MODEL 40n – Coaxial In" → "Coaxial In").
    private static func stripPlayerPrefix(_ name: String) -> String {
        for separator in [" – ", " - "] {
            if let range = name.range(of: separator) {
                let suffix = String(name[range.upperBound...])
                if !suffix.isEmpty { return suffix }
            }
        }
        return name
    }

    // MARK: - Active Detection

    private func isActiveInput(_ item: BrowseItem) -> Bool {
        guard let mid = item.mid, let activeMID = activeInputMID, !activeMID.isEmpty else {
            return false
        }
        return mid == activeMID
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: DS.Spacing.md) {
            Image(systemName: DS.Icons.cableConnector)
                .font(DS.IconFont.jumbo)
                .foregroundStyle(DS.Colors.textTertiary)
            Text("No Inputs")
                .typography(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, DS.Spacing.xxl)
    }
}

// MARK: - Input Card Button

private struct InputCardButton: View {
    let icon: String
    let name: String
    let isActive: Bool
    let accessibilityID: String
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: DS.Spacing.md) {
                ZStack {
                    Circle()
                        .fill(isActive ? DS.Colors.accent.opacity(0.15) : DS.Colors.surfaceElevated)
                        .frame(width: 52, height: 52)

                    Image(systemName: icon)
                        .font(DS.IconFont.xxl)
                        .foregroundStyle(isActive ? DS.Colors.accent : DS.Colors.textSecondary)
                }

                Text(name)
                    .typography(.secondary)
                    .foregroundStyle(isActive ? .primary : DS.Colors.textSecondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(height: 32, alignment: .top)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DS.Spacing.lg)
            .padding(.horizontal, DS.Spacing.xs)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.large)
                    .fill(isHovered ? DS.Colors.surfaceElevated.opacity(0.6) : .clear)
            )
            .overlay(alignment: .topTrailing) {
                if isActive {
                    Circle()
                        .fill(DS.Colors.accent)
                        .frame(width: 8, height: 8)
                        .padding(DS.Spacing.sm)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .contentShape(Rectangle())
            .onHover { isHovered = $0 }
            .animation(.easeInOut(duration: DS.Animation.quick), value: isActive)
            .animation(.easeInOut(duration: DS.Animation.quick), value: isHovered)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(accessibilityID)
        .accessibilityLabel(name)
        .accessibilityAddTraits(.isButton)
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }
}
