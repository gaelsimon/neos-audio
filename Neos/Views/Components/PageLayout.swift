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
