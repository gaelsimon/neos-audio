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

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && URL(webAddress: streamURL) != nil
    }

    var body: some View {
        FormSheet(
            title: "Add Station", confirmTitle: "Add", canConfirm: isValid && !isSaving,
            onCancel: onDismiss, onConfirm: save
        ) {
            Section {
                TextField("Name", text: $name, prompt: Text("Station name"))
                TextField("Stream URL", text: $streamURL, prompt: Text(verbatim: "https://example.com/stream.mp3"))
                    .literalTextInput(.url)
            } footer: {
                Text("The stream's address starts with http:// or https://.")
            }

            Section("Artwork") {
                if let previewImage {
                    Image(platformImage: previewImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 80, height: 80)
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.small))
                        .frame(maxWidth: .infinity)
                }
                ArtworkChooser { previewImage = $0 }
            }

            if isSaving {
                Section {
                    HStack(spacing: DS.Spacing.sm) {
                        Spinner(size: 14, lineWidth: 1.5)
                        Text("Adding…")
                            .typography(.secondary)
                    }
                }
            }
        }
    }

    // MARK: - Actions

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
