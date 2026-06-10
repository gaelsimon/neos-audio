import SwiftUI
import AppKit
import NeosDomain
import UniformTypeIdentifiers

/// Popover form for adding a new favorite station by name and stream URL.
struct AddFavoriteForm: View {
    let browseVM: BrowseViewModel
    let state: AppState
    let onDismiss: () -> Void

    @State private var name = ""
    @State private var streamURL = ""
    @State private var isSaving = false

    // Artwork
    @State private var previewImage: NSImage?
    @State private var pendingImageFileURL: URL?
    @State private var showURLField = false
    @State private var imageURLText = ""
    @State private var isDownloadingImage = false

    private var isValid: Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedURL = streamURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty, !trimmedURL.isEmpty else { return false }
        guard let url = URL(string: trimmedURL),
              let scheme = url.scheme,
              scheme == "http" || scheme == "https" else { return false }
        return true
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            Text("Add Station")
                .typography(.sectionHeader)

            // Name field
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                Text("Name")
                    .typography(.secondary)
                TextField("Station name", text: $name)
                    .textFieldStyle(.roundedBorder)
            }

            // Stream URL field
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                Text("Stream URL")
                    .typography(.secondary)
                TextField("https://example.com/stream.mp3", text: $streamURL)
                    .textFieldStyle(.roundedBorder)
            }

            // Artwork section
            artworkSection

            // Actions
            HStack {
                Spacer()

                Button("Cancel", action: onDismiss)

                Button("Add") { save() }
                    .buttonStyle(.borderedProminent)
                    .tint(DS.Colors.accent)
                    .disabled(!isValid || isSaving)
            }

            if isSaving {
                HStack {
                    Spacer()
                    Spinner(size: 14, lineWidth: 1.5)
                    Text("Adding…")
                        .typography(.secondary)
                    Spacer()
                }
            }
        }
        .padding(DS.Spacing.xl)
        .frame(width: 300)
    }

    // MARK: - Artwork Section

    @ViewBuilder
    private var artworkSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text("Artwork (optional)")
                .typography(.secondary)

            if let previewImage {
                Image(nsImage: previewImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 80, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.small))
                    .frame(maxWidth: .infinity)
            }

            Button {
                chooseLocalImage()
            } label: {
                Label("Choose Image…", systemImage: "folder")
                    .frame(maxWidth: .infinity)
            }

            if showURLField {
                HStack(spacing: DS.Spacing.sm) {
                    TextField("https://example.com/image.png", text: $imageURLText)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { downloadImageFromURL() }
                    if isDownloadingImage {
                        Spinner(size: 14, lineWidth: 1.5)
                    } else {
                        Button("Fetch") { downloadImageFromURL() }
                            .disabled(imageURLText.isEmpty)
                    }
                }
            } else {
                Button("Or paste an image URL…") { showURLField = true }
                    .buttonStyle(.plain)
                    .typography(.secondary)
                    .foregroundStyle(DS.Colors.accent)
            }
        }
    }

    // MARK: - Actions

    private func chooseLocalImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = "Choose an artwork image"

        guard panel.runModal() == .OK, let sourceURL = panel.url else { return }
        guard let image = NSImage(contentsOf: sourceURL) else { return }

        let mid = streamURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let key = mid.isEmpty ? UUID().uuidString : mid
        if let dest = StationImageEditor.copyToAppSupport(image: image, forMID: key) {
            previewImage = image
            pendingImageFileURL = dest
        }
    }

    private func downloadImageFromURL() {
        let trimmed = imageURLText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed),
              let scheme = url.scheme,
              scheme == "http" || scheme == "https" else { return }

        isDownloadingImage = true
        Task {
            do {
                let (data, _) = try await NeosURLSession.shared.data(from: url)
                guard let image = NSImage(data: data) else {
                    isDownloadingImage = false
                    return
                }
                let mid = streamURL.trimmingCharacters(in: .whitespacesAndNewlines)
                let key = mid.isEmpty ? UUID().uuidString : mid
                if let dest = StationImageEditor.copyToAppSupport(image: image, forMID: key) {
                    previewImage = image
                    pendingImageFileURL = dest
                }
            } catch {
                // Download failed; user can retry
            }
            isDownloadingImage = false
        }
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedURL = streamURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty, !trimmedURL.isEmpty else { return }

        isSaving = true
        Task {
            do {
                try await browseVM.addFavorite(name: trimmedName, url: trimmedURL)

                // Set custom artwork if provided
                if let pendingImageFileURL {
                    state.setCustomStationImage(url: pendingImageFileURL.absoluteString, forMID: trimmedURL)
                }

                onDismiss()
            } catch {
                state.showToast("Failed to add station", icon: DS.Icons.warning, style: .error)
            }
            isSaving = false
        }
    }
}
