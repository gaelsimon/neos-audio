import Foundation
import Testing
import NeosDomain
@testable import Neos

struct SourceSectionsTests {
    private let tidal = MusicSource(sid: 10, name: "Tidal", type: "music_service", available: true)
    private let qobuz = MusicSource(sid: 30, name: "Qobuz", type: "music_service", available: false)
    private let nas = MusicSource(sid: 1024, name: "Local Music", type: "heos_server")
    private let aux = MusicSource(sid: 1027, name: "AUX Input", type: "heos_service")
    private let history = MusicSource(sid: 1026, name: "History", imageURL: "https://x/history.png", type: "heos_service")

    @Test func servicesLeaveOutTheLibraryAndTheLocalSources() {
        let sections = SourceSections(sources: [tidal, nas, history], signedIn: false, hidden: [])
        #expect(sections.services.map(\.sid) == [10])
    }

    @Test func localSourcesLeaveOutTheLibrary() {
        let sections = SourceSections(sources: [tidal, nas, aux, history], signedIn: false, hidden: [])
        #expect(sections.local.map(\.sid) == [1024, 1027])
    }

    @Test func hiddenSourcesAreLeftOut() {
        let sections = SourceSections(sources: [tidal, qobuz, nas], signedIn: false, hidden: [30, 1024])
        #expect(sections.services.map(\.sid) + sections.local.map(\.sid) == [10])
    }

    @Test func hidingTheOnlyLinkedServiceLeavesNoService() {
        let sections = SourceSections(sources: [tidal, qobuz], signedIn: true, hidden: [10])
        #expect(sections.services.isEmpty)
    }

    @Test func theLibraryListsFavoritesPlaylistsAndHistoryInThatOrder() {
        let sections = SourceSections(sources: [], signedIn: false, hidden: [])
        #expect(sections.library.map(\.title) == ["Favorites", "Playlists", "History"])
    }

    @Test func aLibraryEntryOpensTheSpeakersOwnSource() {
        let sections = SourceSections(sources: [history], signedIn: false, hidden: [])
        #expect(sections.library.last?.source == history)
    }

    @Test func aLibrarySourceTheSpeakerDidNotListStillOpensBySID() {
        let sections = SourceSections(sources: [], signedIn: false, hidden: [])
        #expect(sections.library.map(\.source.sid) == [1028, 1025, 1026])
    }
}
