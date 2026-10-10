import Foundation
import NeosDomain

@Observable
@MainActor
final class LocalServersViewModel {
    struct Server: Identifiable, Equatable {
        let name: String
        let isOnline: Bool
        var id: String { name }
    }

    let preferences: LocalServerPreferences
    private let service: any AudioService
    private(set) var servers: [Server] = []
    private(set) var hasLoaded = false

    init(service: any AudioService, preferences: LocalServerPreferences) {
        self.service = service
        self.preferences = preferences
    }

    // Servers with a setting stay listed while offline, so a hidden one can always come back.
    func load() async {
        let result = try? await service.browseSource(sid: HEOSConstants.localMusicSID)
        var seen = Set<String>()
        let online = (result?.items ?? []).filter(\.isMediaServer).map(\.name).filter { seen.insert($0).inserted }
        let offline = preferences.rememberedNames.subtracting(online).sorted()
        servers = online.map { Server(name: $0, isOnline: true) }
            + offline.map { Server(name: $0, isOnline: false) }
        hasLoaded = true
    }
}
