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

    var body: some View {
        FormSheet(
            title: "Custom Artwork", confirmTitle: "Save", canConfirm: pendingImage != nil,
            onCancel: onDismiss, onConfirm: save
        ) {
            Section(name) {
                imagePreview
                    .frame(width: 120, height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.medium))
                    .frame(maxWidth: .infinity)

                ArtworkChooser { image in
                    previewImage = image
                    pendingImage = image
                }
            }

            if state.hasCustomStationImage(forMID: mid) {
                Section {
                    Button("Remove Artwork", role: .destructive, action: removeArtwork)
                }
            }
        }
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
