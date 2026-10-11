import NeosDomain

extension MusicSource {
    /// Signed out, or in a session the speaker reports as signed in while refusing every service, it marks them
    /// all unavailable, TuneIn included, though TuneIn needs no account. Only a session with at least one
    /// available service can tell a linked service from an unlinked one.
    static func listed(_ sources: [MusicSource], signedIn: Bool) -> [MusicSource] {
        let services = sources.filter { $0.type == "music_service" }
        let trustAvailability = signedIn && services.contains(where: \.available)
        return trustAvailability ? services.filter(\.available) : services
    }
}
