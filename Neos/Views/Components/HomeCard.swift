import SwiftUI
import NeosDomain

struct HomeCard: View {
    let imageURL: String
    let title: String
    var subtitle: String?
    var isCircular: Bool = false
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                CachedAsyncImage(
                    url: URL(string: imageURL),
                    highResURL: ImageURLUpscaler.highResURL(from: imageURL).flatMap(URL.init(string:))
                ) {
                    Group {
                        if isCircular {
                            Circle()
                                .fill(.quaternary)
                        } else {
                            RoundedRectangle(cornerRadius: DS.Radius.medium)
                                .fill(.quaternary)
                        }
                    }
                    .overlay {
                        Image(systemName: DS.Icons.musicNote)
                            .typography(.pageTitle)
                            .foregroundStyle(DS.Colors.textTertiary)
                    }
                }
                .frame(width: DS.ImageSize.homeCard, height: DS.ImageSize.homeCard)
                .clipShape(isCircular ? AnyShape(Circle()) : AnyShape(RoundedRectangle(cornerRadius: DS.Radius.medium)))

                Text(title)
                    .typography(.secondaryEmphasis)
                    .lineLimit(1)
                    .frame(width: DS.ImageSize.homeCard, alignment: .leading)

                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .typography(.secondary)
                        .lineLimit(1)
                        .frame(width: DS.ImageSize.homeCard, alignment: .leading)
                }
            }
        }
        .buttonStyle(.plain)
    }
}
