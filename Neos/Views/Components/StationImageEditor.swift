import SwiftUI
import CommonCrypto

/// The chosen image is copied to Application Support on save, so it shows offline.
struct StationImageEditor: View {
    let mid: String
    let name: String
    let currentImageURL: String
    let state: AppState
    let onDismiss: () -> Void

    @State private var previewImage: PlatformImage?
    /// Set once the user picks or fetches an image, and copied to disk only on save.
    @State private var pendingImage: PlatformImage?
    @State private var showURLField = false
    @State private var urlText = ""
    @State private var isDownloading = false

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            Text("Custom Artwork")
                .typography(.sectionHeader)

            Text(name)
                .typography(.secondary)
                .lineLimit(1)

            // Preview
            imagePreview
                .frame(width: 120, height: 120)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.medium))
                .frame(maxWidth: .infinity)

            ImagePickerButton { image in
                previewImage = image
                pendingImage = image
            }
            .controlSize(.large)

            // Optional URL input
            if showURLField {
                HStack(spacing: DS.Spacing.sm) {
                    TextField("Image URL", text: $urlText, prompt: Text(verbatim: "https://example.com/image.png"))
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { downloadFromURL() }
                    if isDownloading {
                        Spinner(size: 14, lineWidth: 1.5)
                    } else {
                        Button("Fetch") { downloadFromURL() }
                            .disabled(urlText.isEmpty)
                    }
                }
            } else {
                TextActionButton(title: "Or paste a URL…") { showURLField = true }
            }

            // Actions
            HStack {
                if state.hasCustomStationImage(forMID: mid) {
                    Button("Remove") {
                        removeArtwork()
                    }
                    .foregroundStyle(.red)
                }

                Spacer()

                Button("Cancel", action: onDismiss)
                    .keyboardShortcut(.cancelAction)

                Button("Save") { save() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .tint(DS.Colors.accent)
                    .disabled(pendingImage == nil)
            }
        }
        .padding(DS.Spacing.xl)
        .frame(width: 280)
        .onAppear { loadExisting() }
    }

    // MARK: - Preview

    @ViewBuilder
    private var imagePreview: some View {
        if let previewImage {
            Image(platformImage: previewImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else {
            RoundedRectangle(cornerRadius: DS.Radius.medium)
                .fill(DS.Colors.surfaceElevated)
                .overlay {
                    Image(systemName: DS.Icons.radio)
                        .font(DS.IconFont.xxxl)
                        .foregroundStyle(DS.Colors.textTertiary)
                }
        }
    }

    // MARK: - Actions

    /// Shows what is already set. Save stays disabled until a new image is chosen.
    private func loadExisting() {
        guard let existing = state.customStationImages[mid],
              let url = URL(string: existing),
              url.isFileURL else { return }
        previewImage = PlatformImage.load(contentsOf: url)
    }

    private func downloadFromURL() {
        let trimmed = urlText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed),
              let scheme = url.scheme,
              scheme == "http" || scheme == "https" else { return }

        isDownloading = true
        Task {
            do {
                let (data, _) = try await NeosURLSession.shared.data(from: url)
                guard let image = PlatformImage(data: data) else {
                    isDownloading = false
                    return
                }
                previewImage = image
                pendingImage = image
            } catch {
                // Download failed; user can retry
            }
            isDownloading = false
        }
    }

    private func save() {
        guard let pendingImage, let dest = Self.copyToAppSupport(image: pendingImage, forMID: mid) else { return }
        deleteStoredFile(keeping: dest)
        state.setCustomStationImage(url: dest.absoluteString, forMID: mid)
        onDismiss()
    }

    private func removeArtwork() {
        deleteStoredFile(keeping: nil)
        state.removeCustomStationImage(forMID: mid)
        onDismiss()
    }

    /// The artwork already on disk is orphaned as soon as a different image takes its place.
    private func deleteStoredFile(keeping replacement: URL?) {
        guard let existing = state.customStationImages[mid],
              let url = URL(string: existing), url.isFileURL, url != replacement else { return }
        try? FileManager.default.removeItem(at: url)
    }

    // MARK: - File Helpers

    /// Named from the media id and the image bytes: the URL-keyed image cache would keep a replaced artwork.
    static func copyToAppSupport(image: PlatformImage, forMID mid: String) -> URL? {
        guard let png = image.pngRepresentation() else { return nil }

        let dir = URL.applicationSupportDirectory.appendingPathComponent("Neos/CustomArtwork", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let name = "\(sha256Hex(mid))-\(sha256Hex(png).prefix(16)).png"
        let dest = dir.appendingPathComponent(name)

        do {
            try png.write(to: dest, options: .atomic)
            return dest
        } catch {
            return nil
        }
    }

    private static func sha256Hex(_ string: String) -> String {
        sha256Hex(Data(string.utf8))
    }

    private static func sha256Hex(_ data: Data) -> String {
        var hash = [UInt8](repeating: 0, count: 32)
        data.withUnsafeBytes { buffer in
            _ = CC_SHA256(buffer.baseAddress, CC_LONG(buffer.count), &hash)
        }
        return hash.map { String(format: "%02x", $0) }.joined()
    }
}
