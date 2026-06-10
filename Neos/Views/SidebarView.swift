import AppKit
import SwiftUI
import NeosDomain

// MARK: - Sidebar View

struct SidebarView: View {
    let state: AppState
    let browseVM: BrowseViewModel
    let hiddenSIDs: Set<Int>
    var isSearchActive: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            sidebarLogo
                .padding(.horizontal, DS.Sidebar.sectionPadding)
                .padding(.bottom, DS.Spacing.sm)

            ScrollView {
                VStack(spacing: DS.Spacing.sm) {
                    sidebarRow(icon: DS.Icons.home, title: "Home",
                               isSelected: browseVM.currentDestination == .home && !isSearchActive) {
                        browseVM.navigateToHome()
                    }
                    .accessibilityIdentifier(AccessibilityID.Sidebar.home)

                    let nonLibrary = state.musicSources.filter { !HEOSConstants.librarySIDs.contains($0.sid) }
                    let availableServices = nonLibrary.filter { $0.type == "music_service" && $0.available && !hiddenSIDs.contains($0.sid) }
                    let localSources = nonLibrary.filter { $0.type != "music_service" && !hiddenSIDs.contains($0.sid) }

                    if !availableServices.isEmpty {
                        sidebarSection("Services") {
                            ForEach(availableServices) { source in
                                sourceRow(source)
                            }
                        }
                        .accessibilityElement(children: .contain)
                        .accessibilityIdentifier(AccessibilityID.Sidebar.servicesSection)
                    }

                    if !localSources.isEmpty {
                        sidebarSection("Local") {
                            ForEach(localSources) { source in
                                sourceRow(source)
                            }
                        }
                    }

                    sidebarSection("Library") {
                        libraryRow(sid: 1028, name: "Stations", icon: DS.Icons.radio)
                        libraryRow(sid: 1025, name: "Playlists", icon: DS.Icons.playlists)
                        libraryRow(sid: 1026, name: "History", icon: DS.Icons.history)
                        queueRow
                    }
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier(AccessibilityID.Sidebar.librarySection)
                }
                .padding(DS.Sidebar.sectionPadding)
            }
            .accessibilityIdentifier(AccessibilityID.Sidebar.scrollView)
        }
        .background(DS.Colors.background)
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(DS.Colors.border)
                .frame(width: 1)
        }
    }

    // MARK: - Sidebar Logo

    private var sidebarLogo: some View {
        HStack {
            Image("NeosLogo")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(height: 22)
            Spacer()
        }
        .padding(.horizontal, DS.Sidebar.itemPaddingH)
        .padding(.top, DS.Spacing.sm)
    }

    // MARK: - Section Header

    private func sidebarSection(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            Text(title)
                .typography(.sidebarSection)
                .padding(.horizontal, DS.Sidebar.itemPaddingH)
                .padding(.top, DS.Spacing.sm)

            content()
        }
    }

    // MARK: - Unified Source Row

    private func sourceRow(_ source: MusicSource) -> some View {
        let isSelected = !isSearchActive && browseVM.isBrowsing(sid: source.sid)
        return Button(action: { browseVM.selectSource(source) }) {
            HStack(spacing: DS.Spacing.sm) {
                ServiceBranding.serviceIcon(for: source, size: DS.ImageSize.sidebarIcon)

                Text(source.name)
                    .typography(isSelected ? .bodyEmphasis : .bodyPrimary)
                    .lineLimit(1)

                Spacer()
            }
            .contentShape(Rectangle())
            .sidebarItemStyle(isSelected: isSelected)
        }
        .buttonStyle(.plain)
        .opacity(source.available ? 1 : 0.6)
        .accessibilityIdentifier(AccessibilityID.Sidebar.source(source.sid))
    }

    // MARK: - Sidebar Rows

    private func sidebarRow(icon: String, title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: icon)
                    .typography(.bodyPrimary)
                    .foregroundStyle(DS.Colors.textSecondary)
                    .frame(width: DS.ImageSize.sidebarIcon, height: DS.ImageSize.sidebarIcon)
                    .background(.black, in: RoundedRectangle(cornerRadius: DS.Radius.small))

                Text(title)
                    .typography(isSelected ? .bodyEmphasis : .bodyPrimary)
                    .lineLimit(1)

                Spacer()
            }
            .contentShape(Rectangle())
            .sidebarItemStyle(isSelected: isSelected)
        }
        .buttonStyle(.plain)
    }

    private func libraryRow(sid: Int, name: String, icon: String) -> some View {
        let isSelected = !isSearchActive && browseVM.isBrowsing(sid: sid)
        let source = state.musicSources.first(where: { $0.sid == sid })
            ?? MusicSource(sid: sid, name: name)
        return sidebarRow(icon: icon, title: name, isSelected: isSelected) {
            browseVM.selectSource(source)
        }
    }

    private var queueRow: some View {
        let isSelected = !isSearchActive && browseVM.currentDestination == .queue
        return Button(action: { browseVM.selectQueue() }) {
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: DS.Icons.queue)
                    .typography(.bodyPrimary)
                    .foregroundStyle(DS.Colors.textSecondary)
                    .frame(width: DS.ImageSize.sidebarIcon, height: DS.ImageSize.sidebarIcon)
                    .background(.black, in: RoundedRectangle(cornerRadius: DS.Radius.small))

                Text("Queue")
                    .typography(isSelected ? .bodyEmphasis : .bodyPrimary)
                    .lineLimit(1)

                Spacer()

                if !state.queue.isEmpty {
                    Text("\(state.queue.count)")
                        .typography(.badge)
                        .foregroundStyle(DS.Colors.textSecondary)
                        .padding(.horizontal, DS.Spacing.sm)
                        .padding(.vertical, DS.Spacing.xs)
                        .background(.quaternary, in: Capsule())
                }
            }
            .contentShape(Rectangle())
            .sidebarItemStyle(isSelected: isSelected)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(AccessibilityID.Sidebar.queue)
    }
}

// MARK: - Sidebar Item Style

private struct SidebarItemStyleModifier: ViewModifier {
    let isSelected: Bool
    @State private var isHovered = false

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, DS.Sidebar.itemPaddingH)
            .padding(.vertical, DS.Sidebar.itemPaddingV)
            .background(
                backgroundColor,
                in: RoundedRectangle(cornerRadius: DS.Sidebar.cornerRadius)
            )
            .onHover { hovering in
                isHovered = hovering
                if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
            }
    }

    private var backgroundColor: Color {
        if isSelected {
            return DS.Sidebar.selectedBackground
        } else if isHovered {
            return DS.Sidebar.selectedBackground.opacity(0.5)
        } else {
            return DS.Sidebar.defaultBackground
        }
    }
}

private extension View {
    func sidebarItemStyle(isSelected: Bool) -> some View {
        modifier(SidebarItemStyleModifier(isSelected: isSelected))
    }
}
