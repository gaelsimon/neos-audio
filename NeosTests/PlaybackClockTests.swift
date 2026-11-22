import XCTest
@testable import Neos

final class PlaybackClockTests: XCTestCase {
    private let reportedAt = Date(timeIntervalSinceReferenceDate: 1_000)

    private func position(isPlaying: Bool = true, after seconds: TimeInterval, duration: Int = 180_000) -> Int {
        PlaybackClock.position(
            reported: 60_000, duration: duration, reportedAt: reportedAt,
            isPlaying: isPlaying, at: reportedAt.addingTimeInterval(seconds)
        )
    }

    func testPlaybackRunsOnFromTheLastReport() {
        XCTAssertEqual(position(after: 2.5), 62_500)
    }

    func testAPausedTrackStaysWhereItWasReported() {
        XCTAssertEqual(position(isPlaying: false, after: 10), 60_000)
    }

    func testAClockBehindTheReportKeepsTheReport() {
        XCTAssertEqual(position(after: -1), 60_000)
    }

    func testPlaybackStopsAtTheEndOfTheTrack() {
        XCTAssertEqual(position(after: 600), 180_000)
    }

    func testTheFractionIsTheShareOfTheTrack() {
        let fraction = PlaybackClock.fraction(
            reported: 45_000, duration: 180_000, reportedAt: reportedAt, isPlaying: false, at: reportedAt
        )
        XCTAssertEqual(fraction, 0.25, accuracy: 0.0001)
    }

    func testATrackWithoutDurationHasNoFraction() {
        let fraction = PlaybackClock.fraction(
            reported: 45_000, duration: 0, reportedAt: reportedAt, isPlaying: true, at: reportedAt
        )
        XCTAssertEqual(fraction, 0)
    }

    func testAPositionPastTheDurationIsAWholeTrack() {
        let fraction = PlaybackClock.fraction(
            reported: 200_000, duration: 180_000, reportedAt: reportedAt, isPlaying: false, at: reportedAt
        )
        XCTAssertEqual(fraction, 1)
    }
}
