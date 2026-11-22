import XCTest
@testable import Neos

/// The volume limit of Settings, on preferences of its own so the developer's stay untouched.
@MainActor
final class SettingsViewModelVolumeLimitTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!
    private let state = AppState()

    override func setUp() {
        super.setUp()
        suiteName = "SettingsViewModelVolumeLimitTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    private func makeSettings() -> SettingsViewModel {
        SettingsViewModel(state: state, defaults: defaults, imageCacheBytes: { 0 }, clearImageCache: {}, copyText: { _ in })
    }

    private func settingsLimitedTo(_ level: Int) -> SettingsViewModel {
        let settings = makeSettings()
        settings.volumeLimitValue = level
        settings.volumeLimitEnabled = true
        return settings
    }

    func testNoLimitAppliesUntilItIsSwitchedOn() {
        _ = makeSettings()

        XCTAssertNil(state.maxVolume)
    }

    func testSwitchingTheLimitOnAppliesItsLevel() {
        _ = settingsLimitedTo(40)

        XCTAssertEqual(state.maxVolume, 40)
    }

    func testSwitchingTheLimitOffLiftsIt() {
        let settings = settingsLimitedTo(40)

        settings.volumeLimitEnabled = false

        XCTAssertNil(state.maxVolume)
    }

    func testMovingTheLevelMovesTheLimit() {
        let settings = settingsLimitedTo(40)

        settings.volumeLimitValue = 25

        XCTAssertEqual(state.maxVolume, 25)
    }

    func testTheLevelNeverGoesBelowOne() {
        XCTAssertEqual(settingsLimitedTo(0).volumeLimitValue, 1)
    }

    func testTheLevelNeverGoesAboveAHundred() {
        XCTAssertEqual(settingsLimitedTo(500).volumeLimitValue, 100)
    }

    func testASavedLimitAppliesAtLaunch() {
        _ = settingsLimitedTo(30)

        let relaunched = AppState()
        _ = SettingsViewModel(
            state: relaunched, defaults: defaults, imageCacheBytes: { 0 }, clearImageCache: {}, copyText: { _ in }
        )

        XCTAssertEqual(relaunched.maxVolume, 30)
    }

    func testTheLimitHoldsWhenTheSpeakerReportsAHigherOne() {
        _ = settingsLimitedTo(40)

        state.setMaxVolume(57)

        XCTAssertEqual(state.maxVolume, 40)
    }
}
