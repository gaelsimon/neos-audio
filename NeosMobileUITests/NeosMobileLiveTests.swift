import XCTest

/// The iPhone and iPad app against a real speaker on this network. These tests change what the speaker plays, so they
/// only run when asked: `TEST_RUNNER_NEOS_LIVE_TESTS=1 xcodebuild test … -only-testing:NeosMobileUITests/NeosMobileLiveTests`.
/// The app launches once and each test starts where the previous one ended. The speaker is left paused, one track further
/// in its queue. The app runs with its volume limit at `NEOS_LIVE_MAX_VOLUME` (3 unless given), so no control of it can
/// play louder. Volume and stations still stay out: XCUITest cannot place the volume slider (a first try sent the speaker
/// from 3 to 39), and a station saved by URL adds itself to the queue when it plays.
final class NeosMobileLiveTests: XCTestCase {
    private static var app: XCUIApplication!
    private static var isConnected = false

    private var app: XCUIApplication { Self.app }

    override class func setUp() {
        super.setUp()
        guard ProcessInfo.processInfo.environment["NEOS_LIVE_TESTS"] == "1" else { return }
        app = XCUIApplication()
        let loudest = ProcessInfo.processInfo.environment["NEOS_LIVE_MAX_VOLUME"] ?? "3"
        app.launchArguments = ["-settings.volumeLimitEnabled", "YES", "-settings.volumeLimitValue", loudest]
        app.launch()
        let card = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'discovery.deviceCard'")).firstMatch
        if card.waitForExistence(timeout: 25) { card.tap() }
        let home = app.tabBars.buttons["Home"]
        isConnected = home.waitForExistence(timeout: 30)
        // The tabs exist before the connection screen has faded, and a tap sent meanwhile is lost.
        let faded = Date().addingTimeInterval(10)
        while isConnected, !home.isHittable, Date() < faded {
            Thread.sleep(forTimeInterval: 0.2)
        }
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
        try XCTSkipUnless(ProcessInfo.processInfo.environment["NEOS_LIVE_TESTS"] == "1", "Live tests run on request only")
        try XCTSkipUnless(Self.isConnected, "No speaker answered on this network")
    }

    // MARK: - Helpers

    /// What the mini player says is on: its text is the button just before the transport.
    private var nowPlaying: String {
        let labels = app.buttons.allElementsBoundByIndex.map(\.label)
        guard let transport = labels.firstIndex(where: { $0 == "Play" || $0 == "Pause" }), transport > 0 else { return "" }
        return labels[transport - 1]
    }

    private func waitUntil(_ timeout: TimeInterval = 15, _ condition: () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return true }
            Thread.sleep(forTimeInterval: 0.3)
        }
        return condition()
    }

    private func pauseIfPlaying() {
        let pause = app.buttons["Pause"].firstMatch
        if pause.exists { pause.tap() }
        _ = app.buttons["Play"].firstMatch.waitForExistence(timeout: 10)
    }

    // MARK: - Tests

    func test1TheSpeakerAnswersAndItsSourcesAreListed() {
        app.tabBars.buttons["Library"].tap()
        XCTAssertTrue(app.buttons["Favorites"].waitForExistence(timeout: 30), "The sources never loaded")
        XCTAssertTrue(app.buttons["Queue"].exists)
        XCTAssertFalse(nowPlaying.isEmpty, "The mini player should name what the speaker is on")
    }

    func test2PlayAndPauseReachTheSpeaker() {
        pauseIfPlaying()

        app.buttons["Play"].firstMatch.tap()
        XCTAssertTrue(app.buttons["Pause"].firstMatch.waitForExistence(timeout: 15), "The speaker never reported playing")
        // The button turns at the tap. A pause sent while the speaker still starts the stream is lost: it plays on.
        Thread.sleep(forTimeInterval: 4)

        app.buttons["Pause"].firstMatch.tap()
        XCTAssertTrue(app.buttons["Play"].firstMatch.waitForExistence(timeout: 10), "The speaker never reported paused")
    }

    func test3NextMovesToAnotherTrack() {
        let before = nowPlaying

        app.buttons["Next"].firstMatch.tap()

        XCTAssertTrue(waitUntil { nowPlaying != before && !nowPlaying.isEmpty }, "Still on \(before)")
        pauseIfPlaying()
    }
}
