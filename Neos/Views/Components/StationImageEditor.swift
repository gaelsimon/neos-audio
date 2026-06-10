import SwiftUI
import AppKit
import CommonCrypto
import UniformTypeIdentifiers

/// Popover editor for setting a custom artwork image on a station/track.
/// Images are always copied to Application Support for offline use.
struct StationImageEditor: View {
    let mid: String
    let name: String
    let currentImageURL: String
    let state: AppState
    let onDismiss: () -> Void

    @State private var previewImage: NSImage?
    @State private var pendingFileURL: URL?
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

            // Choose image button
            Button {
                chooseLocalImage()
            } label: {
                Label("Choose Image…", systemImage: "folder")
                    .frame(maxWidth: .infinity)
            }
            .controlSize(.large)

            // Optional URL input
            if showURLField {
                HStack(spacing: DS.Spacing.sm) {
                    TextField("https://example.com/image.png", text: $urlText)
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
                Button("Or paste a URL…") { showURLField = true }
                    .buttonStyle(.plain)
                    .typography(.secondary)
                    .foregroundStyle(DS.Colors.accent)
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

                Button("Save") { save() }
                    .buttonStyle(.borderedProminent)
                    .tint(DS.Colors.accent)
                    .disabled(pendingFileURL == nil)
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
            Image(nsImage: previewImage)
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

    private func loadExisting() {
        guard let existing = state.customStationImages[mid],
              let url = URL(string: existing),
              url.isFileURL,
              let image = NSImage(contentsOf: url) else { return }
        previewImage = image
        pendingFileURL = url
    }

    private func chooseLocalImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = "Choose an artwork image"

        guard panel.runModal() == .OK, let sourceURL = panel.url else { return }
        guard let image = NSImage(contentsOf: sourceURL) else { return }

        if let dest = Self.copyToAppSupport(image: image, forMID: mid) {
            previewImage = image
            pendingFileURL = dest
        }
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
                guard let image = NSImage(data: data) else {
                    isDownloading = false
                    return
                }
                if let dest = Self.copyToAppSupport(image: image, forMID: mid) {
                    previewImage = image
                    pendingFileURL = dest
                }
            } catch {
                // Download failed; user can retry
            }
            isDownloading = false
        }
    }

    private func save() {
        guard let pendingFileURL else { return }
        state.setCustomStationImage(url: pendingFileURL.absoluteString, forMID: mid)
        onDismiss()
    }

    private func removeArtwork() {
        // Delete file from disk
        if let existing = state.customStationImages[mid],
           let url = URL(string: existing), url.isFileURL {
            try? FileManager.default.removeItem(at: url)
        }
        state.removeCustomStationImage(forMID: mid)
        onDismiss()
    }

    // MARK: - File Helpers

    static func copyToAppSupport(image: NSImage, forMID mid: String) -> URL? {
        let dir = URL.applicationSupportDirectory.appendingPathComponent("Neos/CustomArtwork", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let hash = sha256Hex(mid)
        let dest = dir.appendingPathComponent("\(hash).png")

        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else { return nil }

        do {
            try png.write(to: dest, options: .atomic)
            return dest
        } catch {
            return nil
        }
    }

    private static func sha256Hex(_ string: String) -> String {
        let data = Data(string.utf8)
        var hash = [UInt8](repeating: 0, count: 32)
        data.withUnsafeBytes { buffer in
            _ = CC_SHA256(buffer.baseAddress, CC_LONG(buffer.count), &hash)
        }
        return hash.map { String(format: "%02x", $0) }.joined()
    }
}
