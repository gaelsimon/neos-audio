import XCTest
@testable import Neos
import NeosDomain

/// The recently played side of the queue panel: loading the history and playing from it.
@MainActor
final class QueuePanelHistoryTests: XCTestCase {
    private let pastTrack = BrowseItem(name: "Past", mid: "p1", playable: true)
    private let pastStation = BrowseItem(name: "FIP", type: .station, mid: "s1", playable: true)

    private func makePlayingViewModel(_ mock: MockAudioService, state: AppState) -> QueuePanelViewModel {
        state.selectedPlayerID = 42
        return QueuePanelViewModel(service: mock, state: state)
    }

    // MARK: - Loading

    func testLoadedHistoryFillsTheRecentSongs() async {
        let mock = MockAudioService()
        mock.browseResult = BrowseResult(items: [pastTrack])
        let vm = QueuePanelViewModel(service: mock, state: AppState())

        vm.loadHistory()
        await waitUntil { vm.historyVersion == 1 }

        XCTAssertEqual(vm.recentSongs.map(\.name), ["Past"])
    }

    func testLoadedHistoryFillsTheRecentStations() async {
        let mock = MockAudioService()
        mock.browseResult = BrowseResult(items: [pastStation])
        let vm = QueuePanelViewModel(service: mock, state: AppState())

        vm.loadHistory()
        await waitUntil { vm.historyVersion == 1 }

        XCTAssertEqual(vm.recentStations.map(\.name), ["FIP"])
    }

    func testTheFirstHistoryLoadShowsASpinnerUntilItEnds() async {
        let vm = QueuePanelViewModel(service: MockAudioService(), state: AppState())

        vm.loadHistory()

        XCTAssertTrue(vm.isLoadingHistory)
        await waitUntil { !vm.isLoadingHistory }
    }

    func testAHistoryRefreshKeepsTheOldRowsWithoutASpinner() {
        let vm = QueuePanelViewModel(service: MockAudioService(), state: AppState())
        vm.historyTracks = [pastTrack]

        vm.loadHistory()

        XCTAssertFalse(vm.isLoadingHistory)
    }

    func testAFailedHistoryLoadGoesToTheDiagnostics() async {
        let state = AppState()
        let mock = MockAudioService()
        mock.historyError = NSError(domain: "test", code: 1)
        let vm = QueuePanelViewModel(service: mock, state: state)

        vm.loadHistory()
        await waitUntil { !state.diagnostics.isEmpty }

        XCTAssertEqual(state.diagnostics.map(\.source), ["QueuePanelViewModel"])
    }

    func testTheHistoryTabFetchesTheHistoryOnce() async {
        let mock = MockAudioService()
        let vm = QueuePanelViewModel(service: mock, state: AppState())

        vm.loadHistoryIfNeeded()
        await waitUntil { vm.historyVersion == 1 }
        vm.loadHistoryIfNeeded()
        await yieldForTask()

        XCTAssertEqual(mock.calls.filter { $0 == "getHistory" }.count, 1)
    }

    private func makeViewModelOnTheFirstTrack(_ mock: MockAudioService, state: AppState) -> QueuePanelViewModel {
        state.setNowPlaying(NowPlayingMedia(mid: "m1", qid: 1))
        state.setQueue([QueueItem(qid: 1, song: "A", mid: "m1"), QueueItem(qid: 2, song: "B", mid: "m2")])
        return QueuePanelViewModel(service: mock, state: state)
    }

    func testATrackChangeRefetchesTheHistoryWhileThePanelIsOpen() async {
        let state = AppState()
        let mock = MockAudioService()
        let vm = makeViewModelOnTheFirstTrack(mock, state: state)
        state.isQueuePanelOpen = true

        vm.onTrackChanged()

        await waitUntil { mock.calls.contains("getHistory") }
    }

    func testATrackChangeLeavesTheHistoryAloneWhileThePanelIsClosed() async {
        let mock = MockAudioService()
        let vm = makeViewModelOnTheFirstTrack(mock, state: AppState())

        vm.onTrackChanged()
        await yieldForTask()

        XCTAssertFalse(mock.calls.contains("getHistory"))
    }

    func testATrackChangeMovesUpNextWhileThePanelIsClosed() {
        let vm = makeViewModelOnTheFirstTrack(MockAudioService(), state: AppState())

        vm.onTrackChanged()

        XCTAssertEqual(vm.upNextItems.map(\.qid), [2])
    }

    // MARK: - Playing

    func testARecentQueueEntryPlaysFromTheQueue() async {
        let mock = MockAudioService()
        let vm = makePlayingViewModel(mock, state: AppState())

        vm.playRecentItem(.queue(QueueItem(qid: 5, song: "A")))
        await waitUntil { mock.calls.contains { $0.hasPrefix("playQueueItem") } }

        XCTAssertEqual(mock.calls.filter { $0.hasPrefix("playQueueItem") }, ["playQueueItem:42:5"])
    }

    func testARecentStationWithoutASourcePlaysThroughTheHistory() async {
        let mock = MockAudioService()
        let vm = makePlayingViewModel(mock, state: AppState())

        vm.playRecentItem(.history(pastStation))
        await waitUntil { mock.calls.contains { $0.hasPrefix("playStation") } }

        XCTAssertEqual(mock.calls.filter { $0.hasPrefix("playStation") }, ["playStation:42:sid=1026:cid="])
    }

    func testARecentTrackPlaysNow() async {
        let mock = MockAudioService()
        let vm = makePlayingViewModel(mock, state: AppState())

        vm.playRecentItem(.history(pastTrack))
        await waitUntil { mock.calls.contains("addToQueue:42") }

        XCTAssertTrue(mock.calls.contains("addToQueue:42"))
    }

    func testAHistoryItemThatFailsToPlayShowsAnErrorToast() async {
        let state = AppState()
        let mock = MockAudioService()
        mock.addToQueueFailingMIDs = ["p1"]
        let vm = makePlayingViewModel(mock, state: state)

        vm.playHistoryItem(pastTrack)
        await waitUntil { state.toast?.style == .error }

        XCTAssertEqual(state.toast?.text, "addToQueue failed")
    }

    func testAQueueEntryThatFailsToPlayIsReported() async {
        let state = AppState()
        let mock = MockAudioService()
        mock.playQueueItemError = NSError(domain: "test", code: 1)
        let vm = makePlayingViewModel(mock, state: state)

        vm.playQueueItem(QueueItem(qid: 5, song: "A"))
        await waitUntil { state.error != nil }

        XCTAssertNotNil(state.error)
    }

    func testAQueueEntryNeedsASpeakerToPlay() async {
        let mock = MockAudioService()
        let vm = QueuePanelViewModel(service: mock, state: AppState())

        vm.playQueueItem(QueueItem(qid: 5, song: "A"))
        await yieldForTask()

        XCTAssertFalse(mock.calls.contains { $0.hasPrefix("playQueueItem") })
    }

    // MARK: - RecentItem

    func testARecentQueueEntryShowsTheQueueFields() {
        let item = RecentItem.queue(QueueItem(qid: 7, song: "Song", artist: "Artist", imageURL: "https://x/a.jpg", mid: "m7"))

        XCTAssertEqual([item.id, item.name, item.artist, item.imageURL], ["q-7", "Song", "Artist", "https://x/a.jpg"])
    }

    func testARecentHistoryItemShowsTheBrowseFields() {
        let item = RecentItem.history(BrowseItem(name: "Past", imageURL: "https://x/b.jpg", mid: "p1", artist: "Someone"))

        XCTAssertEqual([item.id, item.name, item.artist, item.imageURL], ["h-p1", "Past", "Someone", "https://x/b.jpg"])
    }

    func testAHistoryItemWithoutAMediaIDIsKeyedByItsName() {
        let item = RecentItem.history(BrowseItem(name: "Past"))

        XCTAssertEqual([item.id, item.artist], ["h-Past", ""])
    }

    func testARecentQueueEntryLinksToItsServiceByItsArtwork() {
        XCTAssertEqual(RecentItem.queue(MockData.queueItems[0]).externalLink?.serviceName, "SoundCloud")
    }

    func testARecentStreamLinksToItsAddress() {
        let address = "https://icecast.radiofrance.fr/fip-hifi.aac"
        let item = RecentItem.history(BrowseItem(name: "FIP", type: .station, mid: address))

        guard case .stream(let url) = item.externalLink?.target else { return XCTFail("No stream link") }
        XCTAssertEqual(url.absoluteString, address)
    }
}
