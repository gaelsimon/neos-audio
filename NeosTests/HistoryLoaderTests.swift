import XCTest
@testable import Neos
import NeosDomain

final class HistoryLoaderTests: XCTestCase {

    @MainActor
    func testLoadTracksOnly() async throws {
        let mock = MockAudioService()
        // historyRoot has TRACKS and STATIONS containers
        mock.historyResult = MockData.historyRoot
        // browseContainer returns mock tracks
        mock.browseResult = BrowseResult(items: [
            BrowseItem(name: "Track A", mid: "t1", playable: true),
            BrowseItem(name: "Track B", mid: "t2", playable: true),
        ])

        let result = try await HistoryLoader.load(service: mock, trackLimit: 10)

        XCTAssertEqual(result.tracks.count, 2)
        XCTAssertEqual(result.tracks[0].name, "Track A")
        XCTAssertTrue(result.stations.isEmpty, "Stations should be empty when stationLimit is nil")
        XCTAssertTrue(mock.calls.contains("getHistory"))
        XCTAssertTrue(mock.calls.contains("browseContainer:1026:TRACKS"))
    }

    @MainActor
    func testLoadTracksAndStations() async throws {
        let mock = MockAudioService()
        mock.historyResult = MockData.historyRoot
        mock.browseResult = BrowseResult(items: [
            BrowseItem(name: "Item 1", mid: "m1", playable: true),
        ])

        let result = try await HistoryLoader.load(service: mock, trackLimit: 10, stationLimit: 5)

        // Both sections should be populated (same browseResult returned for both calls)
        XCTAssertFalse(result.tracks.isEmpty)
        XCTAssertFalse(result.stations.isEmpty)
        XCTAssertTrue(mock.calls.contains("browseContainer:1026:TRACKS"))
        XCTAssertTrue(mock.calls.contains("browseContainer:1026:STATIONS"))
    }

    @MainActor
    func testNoContainersUsesTopLevelFallback() async throws {
        let mock = MockAudioService()
        // No browsable containers; just top-level playable items
        mock.historyResult = BrowseResult(items: [
            BrowseItem(name: "Flat Track", mid: "f1", playable: true),
            BrowseItem(name: "Another", mid: "f2", playable: true),
        ])

        let result = try await HistoryLoader.load(service: mock, trackLimit: 10)

        XCTAssertEqual(result.tracks.count, 2)
        XCTAssertEqual(result.tracks[0].name, "Flat Track")
    }

    @MainActor
    func testTrackLimitApplied() async throws {
        let mock = MockAudioService()
        // No browsable containers; fallback to top-level items
        var items: [BrowseItem] = []
        for i in 0..<20 {
            items.append(BrowseItem(name: "Track \(i)", mid: "t\(i)", playable: true))
        }
        mock.historyResult = BrowseResult(items: items)

        let result = try await HistoryLoader.load(service: mock, trackLimit: 5)

        XCTAssertEqual(result.tracks.count, 5)
    }

    @MainActor
    func testUsesHistorySIDConstant() async throws {
        let mock = MockAudioService()
        mock.historyResult = MockData.historyRoot
        mock.browseResult = BrowseResult(items: [])

        _ = try await HistoryLoader.load(service: mock, trackLimit: 10, stationLimit: 5)

        // Verify calls use SID 1026 (HEOSConstants.historySID)
        let containerCalls = mock.calls.filter { $0.hasPrefix("browseContainer:") }
        for call in containerCalls {
            XCTAssertTrue(call.contains(":1026:"), "Expected SID 1026, got: \(call)")
        }
    }
}
