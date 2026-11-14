import SwiftUI

extension EnvironmentValues {
    /// Where a page's title starts. The iPhone and iPad shell sets it from the size class.
    @Entry var pageMargin: CGFloat = DS.Layout.pageMargin

    /// Where a list of rows that pad their own content starts, so the row text meets the title's edge.
    var listMargin: CGFloat { max(0, pageMargin - DS.Layout.listOutdent) }

    /// Too narrow for track columns or for a title beside the container artwork.
    var isCompactLayout: Bool {
        #if os(iOS)
        horizontalSizeClass == .compact
        #else
        false
        #endif
    }

    /// Where a service group's content starts: inside its card, or at the page margin once the group is flat.
    var groupInset: CGFloat { isCompactLayout ? pageMargin : DS.Layout.surfaceInset }

    /// For rows that pad their own content inside a service group.
    var groupListInset: CGFloat { isCompactLayout ? listMargin : 0 }

    /// A flat group's own header outranks its shelves; in a card, the card does that job.
    var groupSectionStyle: DS.Font { isCompactLayout ? .bodyEmphasis : .sectionHeader }
}

extension View {
    /// Lines the content up with the page title.
    func pageMargins() -> some View {
        modifier(SideMargins(margin: \.pageMargin))
    }

    /// For a list of rows that pad their own content.
    func listMargins() -> some View {
        modifier(SideMargins(margin: \.listMargin))
    }

    /// A service's shelves or results: a card on the Mac and iPad. On iPhone the group stays flat, where a card
    /// would cost two margins of width and push its titles off the page's edge.
    func serviceGroupSurface() -> some View {
        modifier(ServiceGroupSurface())
    }

    /// A row that draws its own padding and background, inside a `List` kept for its swipe actions.
    func bareListRow() -> some View {
        listRowInsets(EdgeInsets())
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
    }
}

private struct ServiceGroupSurface: ViewModifier {
    @Environment(\.isCompactLayout) private var isCompactLayout

    func body(content: Content) -> some View {
        if isCompactLayout {
            content
        } else {
            content
                .padding(.vertical, DS.Spacing.xl)
                .background(RoundedRectangle(cornerRadius: DS.Radius.large).fill(DS.Colors.surfaceContainer))
                .pageMargins()
        }
    }
}

private struct SideMargins: ViewModifier {
    @Environment private var margin: CGFloat

    init(margin: KeyPath<EnvironmentValues, CGFloat>) {
        _margin = Environment(margin)
    }

    func body(content: Content) -> some View {
        content.padding(.horizontal, margin)
    }
}
