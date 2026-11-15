import SwiftUI
import NeosDomain

/// Form for adding a new favorite station by name and stream URL.
struct AddFavoriteForm: View {
    let browseVM: BrowseViewModel
    let state: AppState
    let onDismiss: () -> Void

    @State private var name = ""
    @State private var streamURL = ""
    @State private var isSaving = false

    // Artwork, held in memory until the station is actually added.
    @State private var previewImage: PlatformImage?
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
                TextField("Stream URL", text: $streamURL, prompt: Text(verbatim: "https://example.com/stream.mp3"))
                    .textFieldStyle(.roundedBorder)
            }

            // Artwork section
            artworkSection

            // Actions
            HStack {
                Spacer()

                Button("Cancel", action: onDismiss)
                    .keyboardShortcut(.cancelAction)

                Button("Add") { save() }
                    .keyboardShortcut(.defaultAction)
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
                Image(platformImage: previewImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 80, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.small))
                    .frame(maxWidth: .infinity)
            }

            ImagePickerButton { previewImage = $0 }

            if showURLField {
                HStack(spacing: DS.Spacing.sm) {
                    TextField("Image URL", text: $imageURLText, prompt: Text(verbatim: "https://example.com/image.png"))
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
                TextActionButton(title: "Or paste an image URL…") { showURLField = true }
            }
        }
    }

    // MARK: - Actions

    private func downloadImageFromURL() {
        let trimmed = imageURLText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed),
              let scheme = url.scheme,
              scheme == "http" || scheme == "https" else { return }

        isDownloadingImage = true
        Task {
            do {
                let (data, _) = try await NeosURLSession.shared.data(from: url)
                guard let image = PlatformImage(data: data) else {
                    isDownloadingImage = false
                    return
                }
                previewImage = image
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

                // Written only now: a cancelled or failed add must leave nothing on disk.
                if let previewImage,
                   let dest = StationImageEditor.copyToAppSupport(image: previewImage, forMID: trimmedURL) {
                    state.setCustomStationImage(url: dest.absoluteString, forMID: trimmedURL)
                }

                onDismiss()
            } catch {
                state.showToast("Failed to add station", icon: DS.Icons.warning, style: .error)
            }
            isSaving = false
        }
    }
}
