import SwiftUI
import NeosDomain

struct HomeCard: View {
    let imageURL: String
    let title: String
    var subtitle: String?
    var isCircular: Bool = false
    var externalLink: ExternalLinkMenu?
    var state: AppState?
    let onTap: () -> Void

    private var textAlignment: Alignment { isCircular ? .center : .leading }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                CachedAsyncImage(
                    url: URL(string: imageURL),
                    highResURL: ImageURLUpscaler.highResURL(from: imageURL, pixels: 320).flatMap(URL.init(string:))
                ) {
                    Group {
                        if isCircular {
                            Circle()
                                .fill(.quaternary)
                        } else {
                            RoundedRectangle(cornerRadius: DS.Radius.artwork)
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
                .clipShape(isCircular ? AnyShape(Circle()) : AnyShape(RoundedRectangle(cornerRadius: DS.Radius.artwork)))

                Text(title)
                    .typography(.secondaryEmphasis)
                    .lineLimit(1)
                    .frame(width: DS.ImageSize.homeCard, alignment: textAlignment)

                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .typography(.secondary)
                        .lineLimit(1)
                        .frame(width: DS.ImageSize.homeCard, alignment: textAlignment)
                }
            }
        }
        .buttonStyle(.plain)
        .contextMenu(externalLink.map { link in
            ContextMenu { ExternalLinkMenuItems(link: link, state: state) }
        })
    }
}
