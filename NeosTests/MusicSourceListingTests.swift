import Foundation
import Testing
import NeosDomain
@testable import Neos

@Suite("MusicSource listing")
struct MusicSourceListingTests {
    private let tuneIn = MusicSource(sid: 3, name: "TuneIn", type: "music_service", available: false)
    private let tidal = MusicSource(sid: 10, name: "Tidal", type: "music_service", available: true)
    private let qobuz = MusicSource(sid: 30, name: "Qobuz", type: "music_service", available: false)
    private let nas = MusicSource(sid: 1024, name: "Local Music", type: "heos_server", available: true)

    @Test func signedOutListsEveryService() {
        #expect(MusicSource.listed([tuneIn, tidal, qobuz, nas], signedIn: false).map(\.sid) == [3, 10, 30])
    }

    @Test func signedInListsOnlyAvailableServices() {
        #expect(MusicSource.listed([tuneIn, tidal, qobuz, nas], signedIn: true).map(\.sid) == [10])
    }

    @Test func signedInWithNothingAvailableListsEveryService() {
        #expect(MusicSource.listed([tuneIn, qobuz, nas], signedIn: true).map(\.sid) == [3, 30])
    }

    @Test func localSourcesAreNeverServices() {
        #expect(MusicSource.listed([nas], signedIn: false).isEmpty)
        #expect(MusicSource.listed([nas], signedIn: true).isEmpty)
    }
}
