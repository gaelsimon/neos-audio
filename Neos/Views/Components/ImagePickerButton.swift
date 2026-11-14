import SwiftUI
import UniformTypeIdentifiers

/// Picks artwork from disk.
struct ImagePickerButton: View {
    let onPick: (NSImage) -> Void

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
        guard let image = NSImage(contentsOf: url) else { return }
        onPick(image)
    }
}
