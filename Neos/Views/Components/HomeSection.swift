import SwiftUI

struct HomeSection<Content: View>: View {
    let title: String
    var titleStyle: DS.Font = .sectionHeader
    var isLoading: Bool = false
    var onSeeAll: (() -> Void)?
    var inset: CGFloat?
    @ViewBuilder let content: Content
    @Environment(\.pageMargin) private var pageMargin

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            HStack {
                Text(title)
                    .typography(titleStyle)

                if isLoading {
                    Spinner(size: 12, lineWidth: 1.5)
                }

                Spacer()

                if let onSeeAll {
                    TextActionButton(title: "See All", action: onSeeAll)
                }
            }
            .padding(.horizontal, inset ?? pageMargin)

            content
        }
    }
}
