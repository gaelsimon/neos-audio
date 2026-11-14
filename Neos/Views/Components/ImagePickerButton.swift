import SwiftUI
import UniformTypeIdentifiers
#if os(iOS)
import PhotosUI
#endif

/// Picks artwork from disk on macOS and from the photo library on iOS.
struct ImagePickerButton: View {
    let onPick: (PlatformImage) -> Void

    #if os(macOS)
    @State private var isChoosingFile = false

    var body: some View {
        Button { isChoosingFile = true } label: {
            Label("Choose Image…", systemImage: "folder")
                .frame(maxWidth: .infinity)
        }
        .fileImporter(isPresented: $isChoosingFile, allowedContentTypes: [.image]) { result in
            if case .success(let url) = result { load(url) }
        }
    }

    private func load(_ url: URL) {
        let isScoped = url.startAccessingSecurityScopedResource()
        defer { if isScoped { url.stopAccessingSecurityScopedResource() } }
        guard let image = PlatformImage.load(contentsOf: url) else { return }
        onPick(image)
    }
    #else
    @State private var selection: PhotosPickerItem?

    var body: some View {
        PhotosPicker(selection: $selection, matching: .images) {
            Label("Choose Image…", systemImage: "photo")
                .frame(maxWidth: .infinity)
        }
        .onChange(of: selection) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    onPick(image)
                }
                selection = nil
            }
        }
    }
    #endif
}
