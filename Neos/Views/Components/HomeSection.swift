import SwiftUI

struct HomeSection<Content: View>: View {
    let title: String
    var isLoading: Bool = false
    var onSeeAll: (() -> Void)?
    var inset: CGFloat = DS.Layout.pageMargin
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
                    TextActionButton(title: "See All", action: onSeeAll)
                }
            }
            .padding(.horizontal, inset)

            content
        }
    }
}
