import SwiftUI

/// The two ways to give a station its artwork: a file or photo, or an image on the web.
struct ArtworkChooser: View {
    let onPick: (PlatformImage) -> Void

    @State private var urlText = ""
    @State private var isDownloading = false
    private static let example = "https://example.com/image.png" // NOSONAR: an example in an empty field, never opened

    var body: some View {
        ImagePickerButton(onPick: onPick)

        HStack(spacing: DS.Spacing.sm) {
            TextField("Image URL", text: $urlText, prompt: Text(verbatim: Self.example))
                .literalTextInput(.url)
                .onSubmit(download)
            if isDownloading {
                Spinner(size: 14, lineWidth: 1.5)
            } else {
                Button("Fetch", action: download)
                    .buttonStyle(.borderless)
                    .disabled(URL(webAddress: urlText) == nil)
            }
        }
    }

    private func download() {
        guard let url = URL(webAddress: urlText) else { return }
        isDownloading = true
        Task {
            if let (data, _) = try? await NeosURLSession.shared.data(from: url), let image = PlatformImage(data: data) {
                onPick(image)
            }
            isDownloading = false
        }
    }
}
