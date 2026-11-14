import SwiftUI
import NeosDomain

/// The sources as a list, where the Mac has its sidebar.
struct LibraryView: View {
    let state: AppState
    let container: ViewModelContainer
    let model: BrowseViewModel

    var body: some View {
        let others = state.musicSources.filter { !HEOSConstants.librarySIDs.contains($0.sid) }
        let hidden = container.homeVM.hiddenSIDs
        let services = MusicSource.listed(others, signedIn: state.signedInUser != nil).filter { !hidden.contains($0.sid) }
        let local = others.filter { $0.type != "music_service" && !hidden.contains($0.sid) }

        List {
            if !services.isEmpty {
                Section("Services") {
                    ForEach(services) { sourceRow($0) }
                }
            }
            if !local.isEmpty {
                Section("Local") {
                    ForEach(local) { sourceRow($0) }
                }
            }
            Section("Library") {
                libraryRow(sid: HEOSConstants.favoritesSID, name: "Favorites", icon: DS.Icons.radio)
                libraryRow(sid: 1025, name: "Playlists", icon: DS.Icons.playlists)
                libraryRow(sid: HEOSConstants.historySID, name: "History", icon: DS.Icons.historyUnfilled)
                Button { model.selectQueue() } label: {
                    Label("Queue", systemImage: DS.Icons.queue)
                }
            }
        }
        .navigationTitle("Library")
    }

    private func sourceRow(_ source: MusicSource) -> some View {
        Button { model.selectSource(source) } label: {
            Label {
                Text(source.name)
            } icon: {
                ServiceBranding.serviceIcon(for: source, size: 28)
            }
        }
        .disabled(!source.available)
    }

    private func libraryRow(sid: Int, name: String, icon: String) -> some View {
        let source = state.musicSources.first { $0.sid == sid } ?? MusicSource(sid: sid, name: name)
        return Button { model.selectSource(source) } label: {
            Label(name, systemImage: icon)
        }
    }
}
