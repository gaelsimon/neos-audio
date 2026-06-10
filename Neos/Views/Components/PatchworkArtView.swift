import SwiftUI

struct PatchworkArtView: View {
    let imageURLs: [String]
    let size: CGFloat
    let cornerRadius: CGFloat

    var body: some View {
        let urls = uniquePrefix(imageURLs, count: 4)

        if urls.count >= 4 {
            mosaic(urls)
        } else if urls.count >= 1 {
            // Not enough unique images; use first one
            CachedAsyncImage(
                url: URL(string: urls[0]),
                highResURL: ImageURLUpscaler.highResURL(from: urls[0]).flatMap(URL.init(string:))
            ) {
                placeholder
            }
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        } else {
            placeholder
        }
    }

    private func mosaic(_ urls: [String]) -> some View {
        let cellSize = size / 2
        return VStack(spacing: 0) {
            HStack(spacing: 0) {
                cell(urls[0], size: cellSize)
                cell(urls[1], size: cellSize)
            }
            HStack(spacing: 0) {
                cell(urls[2], size: cellSize)
                cell(urls[3], size: cellSize)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }

    private func cell(_ url: String, size: CGFloat) -> some View {
        CachedAsyncImage(
            url: URL(string: url),
            highResURL: ImageURLUpscaler.highResURL(from: url).flatMap(URL.init(string:))
        ) {
            Rectangle().fill(DS.Colors.surfaceElevated)
        }
        .frame(width: size, height: size)
        .clipped()
    }

    private var placeholder: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(DS.Colors.surfaceElevated)
            .frame(width: size, height: size)
            .overlay {
                Image(systemName: DS.Icons.musicNote)
                    .font(size > 60 ? DS.IconFont.xxxl : DS.IconFont.body)
                    .foregroundStyle(DS.Colors.textTertiary)
            }
    }

    /// Deduplicate URLs preserving order
    private func uniquePrefix(_ urls: [String], count: Int) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for url in urls where seen.insert(url).inserted {
            result.append(url)
            if result.count == count { break }
        }
        return result
    }
}
