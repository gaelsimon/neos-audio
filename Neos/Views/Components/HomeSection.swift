import SwiftUI

struct HomeSection<Content: View>: View {
    let title: String
    var isLoading: Bool = false
    var onSeeAll: (() -> Void)?
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            HStack {
                Text(title)
                    .typography(.sectionHeader)

                if isLoading {
                    Spinner(size: 12, lineWidth: 1.5)
                }

                Spacer()

                if let onSeeAll {
                    HoverButton(action: onSeeAll) { hovered in
                        Text("See All")
                            .typography(.secondary)
                            .foregroundStyle(hovered ? .white : DS.Colors.textSecondary)
                    }
                }
            }
            .padding(.horizontal, DS.Spacing.xl)

            content
        }
    }
}
