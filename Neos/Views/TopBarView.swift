import SwiftUI
import NeosDomain

struct TopBarView: View {
    let state: AppState
    let container: ViewModelContainer

    private var browseVM: BrowseViewModel { container.browseVM }
    private var searchVM: SearchViewModel { container.searchVM }

    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            HStack(spacing: 0) {
                navArrowButton(
                    icon: DS.Icons.back,
                    enabled: container.canGoBack,
                    accessibilityID: AccessibilityID.TopBar.backButton,
                    action: { container.goBack() }
                )

                navArrowButton(
                    icon: DS.Icons.forward,
                    enabled: container.canGoForward,
                    accessibilityID: AccessibilityID.TopBar.forwardButton,
                    action: { container.goForward() }
                )
            }
            .background { GlassCapsule() }

            Spacer(minLength: DS.Spacing.sm)

            searchField

            speakerIndicator

            profileButton
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.top, DS.Spacing.sm)
        .frame(maxWidth: .infinity)
        .frame(height: DS.TopBar.height)
    }

    // MARK: - Search Field

    private var searchField: some View {
        HStack(spacing: DS.Spacing.sm) {
            Image(systemName: DS.Icons.search)
                .font(DS.IconFont.body)
                .foregroundStyle(DS.Colors.textSecondary)
            NoRingTextField(
                placeholder: "Search",
                text: Binding(
                    get: { searchVM.query },
                    set: { searchVM.onQueryChanged($0) }
                ),
                isFocused: Binding(
                    get: { state.isSearchFieldFocused },
                    set: { state.isSearchFieldFocused = $0 }
                ),
                accessibilityID: AccessibilityID.TopBar.searchField
            )
            .accessibilityIdentifier(AccessibilityID.TopBar.searchField)
            if !searchVM.query.isEmpty {
                HoverButton(action: { searchVM.clearSearch() }) { hovered in
                    Image(systemName: DS.Icons.close)
                        .font(DS.IconFont.mdEmphasis)
                        .foregroundStyle(hovered ? .white : DS.Colors.textSecondary)
                }
                .accessibilityIdentifier(AccessibilityID.Search.clearButton)
            }
        }
        .padding(.horizontal, DS.Spacing.lg)
        .frame(width: DS.TopBar.searchWidth, height: DS.TopBar.controlHeight)
        .contentShape(Capsule())
        // The text field is narrower than the capsule, so clicking the magnifier or the padding
        // used to do nothing. Simultaneous so a click inside the field still places the cursor.
        .simultaneousGesture(TapGesture().onEnded { state.isSearchFieldFocused = true })
        .background { GlassCapsule(tint: state.isSearchFieldFocused ? .white.opacity(0.08) : .clear) }
        .overlay(
            Capsule()
                .strokeBorder(Color.white.opacity(state.isSearchFieldFocused ? 0.9 : 0), lineWidth: 1)
                .allowsHitTesting(false)
        )
        .animation(.easeInOut(duration: DS.Animation.quick), value: state.isSearchFieldFocused)
        .onChange(of: state.isSearchFieldFocused) { _, focused in
            if focused && !searchVM.query.isEmpty && !searchVM.serviceResults.isEmpty {
                searchVM.activateOverlay()
            }
        }
        .overlay(alignment: .topLeading) {
            if state.isSearchFieldFocused && searchVM.query.isEmpty && !searchVM.recentQueries.isEmpty {
                SearchHistoryOverlay(
                    queries: searchVM.recentQueries,
                    onSelect: { query in
                        state.isSearchFieldFocused = false
                        searchVM.onQueryChanged(query)
                    },
                    onClear: {
                        searchVM.clearHistory()
                    }
                )
                .frame(width: 380)
                .offset(y: 48)
                .zIndex(10)
                .transition(.opacity.combined(with: .move(edge: .top)))
                .animation(.easeInOut(duration: DS.Animation.quick), value: state.isSearchFieldFocused)
            }
        }
    }

    // MARK: - Speaker Indicator

    private var speakerIndicator: some View {
        let isActive = browseVM.currentDestination == .ampSettings
        return HoverButton(action: {
            if isActive {
                browseVM.goBack()
            } else {
                if browseVM.currentDestination == .settings { browseVM.goBack() }
                browseVM.navigateToAmpSettings()
            }
        }) { hovered in
            HStack(spacing: DS.Spacing.sm) {
                Circle()
                    .fill(state.connectionState == .connected ? Color.green : DS.Colors.textTertiary)
                    .frame(width: 7, height: 7)

                Text(state.selectedPlayerDisplayName ?? "No Player")
                    .typography(.secondary)
                    .foregroundStyle(isActive ? DS.Colors.accent : hovered ? .white : DS.Colors.textSecondary)
                    .lineLimit(1)
                    .frame(maxWidth: 160)
                    .fixedSize(horizontal: true, vertical: false)
            }
            .padding(.horizontal, DS.Spacing.md)
            .frame(height: DS.TopBar.controlHeight)
            .background { GlassCapsule(tint: isActive ? DS.Colors.accent.opacity(0.15) : .clear) }
        }
        .accessibilityIdentifier(AccessibilityID.Sidebar.ampCard)
    }

    private var profileButton: some View {
        let isActive = browseVM.currentDestination == .settings
        return HoverButton(action: {
            if isActive {
                browseVM.goBack()
            } else {
                if browseVM.currentDestination == .ampSettings { browseVM.goBack() }
                browseVM.navigateToSettings()
            }
        }) { hovered in
            Image(systemName: DS.Icons.person)
                .font(DS.IconFont.lgEmphasis)
                .foregroundStyle(isActive ? DS.Colors.accent : hovered ? .white : Color.white.opacity(0.7))
                .frame(width: DS.TopBar.controlHeight, height: DS.TopBar.controlHeight)
                .background { GlassCapsule() }
        }
        .accessibilityIdentifier(AccessibilityID.TopBar.profileButton)
    }

    // MARK: - Navigation Arrow

    private func navArrowButton(icon: String, enabled: Bool, accessibilityID: String, action: @escaping () -> Void) -> some View {
        HoverButton(action: action) { hovered in
            Image(systemName: icon)
                .font(DS.TopBar.arrowFont)
                .foregroundStyle(!enabled ? Color.white.opacity(0.25) : .white)
                .frame(width: DS.TopBar.controlHeight, height: DS.TopBar.controlHeight)
                .background(
                    Circle()
                        .fill(Color.white.opacity(enabled && hovered ? 0.15 : 0))
                        .padding(2)
                )
        }
        .disabled(!enabled)
        .accessibilityIdentifier(accessibilityID)
    }
}
