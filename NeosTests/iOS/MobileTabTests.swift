import Testing
import NeosDomain
@testable import Neos

struct MobileTabTests {
    private let tidal = MusicSource(sid: 10, name: "Tidal", type: "music_service", available: true)
    private let nas = MusicSource(sid: 1024, name: "Local Music", type: "heos_server")

    private func sources(hidden: Set<Int> = []) -> SourceSections {
        SourceSections(sources: [tidal, nas], signedIn: true, hidden: hidden)
    }

    @Test(arguments: [MobileTab.home, .library, .search])
    func theThreeMainTabsShowInAnyWindow(tab: MobileTab) {
        #expect(tab.showing(sourceTabs: false, sources: sources()) == tab)
        #expect(tab.showing(sourceTabs: true, sources: sources()) == tab)
    }

    @Test func aSourceKeepsItsTabBesideTheSidebar() {
        #expect(MobileTab.source(10).showing(sourceTabs: true, sources: sources()) == .source(10))
        #expect(MobileTab.source(1024).showing(sourceTabs: true, sources: sources()) == .source(1024))
    }

    @Test func aLibrarySourceAlwaysHasItsTab() {
        let favorites = MobileTab.source(HEOSConstants.favoritesSID)
        #expect(favorites.showing(sourceTabs: true, sources: sources()) == favorites)
    }

    @Test func aNarrowWindowSendsASourceAndTheQueueToTheLibrary() {
        #expect(MobileTab.source(10).showing(sourceTabs: false, sources: sources()) == .library)
        #expect(MobileTab.queue.showing(sourceTabs: false, sources: sources()) == .library)
    }

    @Test func theQueueKeepsItsTabBesideTheSidebar() {
        #expect(MobileTab.queue.showing(sourceTabs: true, sources: sources()) == .queue)
    }

    @Test func aSourceHiddenInSettingsGivesWayToHome() {
        #expect(MobileTab.source(10).showing(sourceTabs: true, sources: sources(hidden: [10])) == .home)
    }

    @Test func aSourceTheSpeakerNoLongerListsGivesWayToHome() {
        #expect(MobileTab.source(99).showing(sourceTabs: true, sources: sources()) == .home)
    }
}
