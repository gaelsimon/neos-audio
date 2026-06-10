import SwiftUI

/// A reusable underline-style tab bar.
///
/// Generic over any `Hashable` tab type. The caller owns the selection via a `@Binding`.
///
///     enum MyTab: Hashable { case first, second }
///     @State private var tab: MyTab = .first
///     SegmentedTab(selection: $tab, tabs: [.first, .second]) { tab in
///         switch tab {
///         case .first: "First"
///         case .second: "Second"
///         }
///     }
struct SegmentedTab<Tab: Hashable>: View {
    @Binding var selection: Tab
    let tabs: [Tab]
    let label: (Tab) -> String

    @Namespace private var underline

    var body: some View {
        HStack(spacing: DS.Spacing.xl) {
            ForEach(tabs, id: \.self) { tab in
                tabButton(tab)
            }
            Spacer()
        }
        .padding(.horizontal, DS.Spacing.lg)
    }

    private func tabButton(_ tab: Tab) -> some View {
        Button {
            withAnimation(.easeInOut(duration: DS.Animation.quick)) {
                selection = tab
            }
        } label: {
            Text(label(tab))
                .font(.system(
                    size: 14,
                    weight: selection == tab ? .semibold : .medium
                ))
                .foregroundStyle(
                    selection == tab
                        ? Color.primary
                        : DS.Colors.textTertiary
                )
                .padding(.vertical, DS.Spacing.lg)
                .overlay(alignment: .bottom) {
                    // Underline indicator; same width as text
                    if selection == tab {
                        Rectangle()
                            .fill(DS.Colors.accent)
                            .frame(height: 2)
                            .matchedGeometryEffect(id: "underline", in: underline)
                    }
                }
        }
        .buttonStyle(.plain)
    }
}
