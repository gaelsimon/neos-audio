import XCTest
@testable import Neos
import NeosDomain

final class AccountViewModelTests: XCTestCase {

    // MARK: - Account change

    @MainActor
    func testSignInReportsTheAccountChange() async {
        let vm = AccountViewModel(service: MockAudioService(), state: AppState())
        var changes = 0
        vm.onAccountChanged = { changes += 1 }

        vm.username = "user"
        vm.password = "pass"
        vm.signIn()
        await waitUntil { !vm.isSigningIn }

        XCTAssertEqual(changes, 1)
    }

    @MainActor
    func testSignOutReportsTheAccountChange() async {
        let state = AppState()
        state.signedInUser = "user"
        let vm = AccountViewModel(service: MockAudioService(), state: state)
        var changes = 0
        vm.onAccountChanged = { changes += 1 }

        vm.signOut()
        await waitUntil { state.signedInUser == nil }

        XCTAssertEqual(changes, 1)
    }

    // MARK: - signIn

    @MainActor
    func testSignInGuardsEmptyUsername() async {
        let state = AppState()
        let mock = MockAudioService()
        let vm = AccountViewModel(service: mock, state: state)

        vm.username = ""
        vm.password = "pass"
        vm.signIn()

        await yieldForTask()
        XCTAssertFalse(vm.isSigningIn)
        XCTAssertNil(state.signedInUser)
    }

    @MainActor
    func testSignInGuardsEmptyPassword() async {
        let state = AppState()
        let mock = MockAudioService()
        let vm = AccountViewModel(service: mock, state: state)

        vm.username = "user"
        vm.password = ""
        vm.signIn()

        await yieldForTask()
        XCTAssertFalse(vm.isSigningIn)
        XCTAssertNil(state.signedInUser)
    }

    @MainActor
    func testSignInSetsLoadingFlag() {
        let state = AppState()
        let mock = MockAudioService()
        let vm = AccountViewModel(service: mock, state: state)

        vm.username = "user"
        vm.password = "pass"
        vm.signIn()

        XCTAssertTrue(vm.isSigningIn)
    }

    @MainActor
    func testSignInSuccessSetsSignedInUser() async {
        let state = AppState()
        let mock = MockAudioService()
        let vm = AccountViewModel(service: mock, state: state)

        vm.username = "user@test.com"
        vm.password = "secret"
        vm.signIn()

        await yieldForTask()
        XCTAssertEqual(state.signedInUser, "user@test.com")
        XCTAssertFalse(vm.isSigningIn)
        XCTAssertNil(vm.signInError)
    }

    @MainActor
    func testSignInFailureSetsError() async {
        let state = AppState()
        let mock = MockAudioService()
        mock.signInError = NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Bad credentials"])
        let vm = AccountViewModel(service: mock, state: state)

        vm.username = "user@test.com"
        vm.password = "wrong"
        vm.signIn()

        await yieldForTask()
        XCTAssertNil(state.signedInUser)
        XCTAssertNotNil(vm.signInError)
        XCTAssertFalse(vm.isSigningIn)
    }

    @MainActor
    func testSignInClearsPreivousError() {
        let state = AppState()
        let mock = MockAudioService()
        let vm = AccountViewModel(service: mock, state: state)

        vm.signInError = .unknown("old error")
        vm.username = "user"
        vm.password = "pass"
        vm.signIn()

        XCTAssertNil(vm.signInError)
    }

    // MARK: - signOut

    @MainActor
    func testSignOutSetsLoadingFlag() {
        let state = AppState()
        let mock = MockAudioService()
        let vm = AccountViewModel(service: mock, state: state)

        vm.signOut()

        XCTAssertTrue(vm.isSigningOut)
    }

    @MainActor
    func testSignOutSuccessClearsUser() async {
        let state = AppState()
        state.signedInUser = "user@test.com"
        let mock = MockAudioService()
        let vm = AccountViewModel(service: mock, state: state)

        vm.signOut()

        await yieldForTask()
        XCTAssertNil(state.signedInUser)
        XCTAssertFalse(vm.isSigningOut)
    }

    @MainActor
    func testSignOutFailureSetsError() async {
        let state = AppState()
        state.signedInUser = "user@test.com"
        let mock = MockAudioService()
        mock.signOutError = NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Network error"])
        let vm = AccountViewModel(service: mock, state: state)

        vm.signOut()

        await yieldForTask()
        // User stays signed in on failure
        XCTAssertEqual(state.signedInUser, "user@test.com")
        XCTAssertNotNil(state.error)
        XCTAssertFalse(vm.isSigningOut)
    }

    // MARK: - checkAccount

    @MainActor
    func testCheckAccountSetsUser() async {
        let state = AppState()
        let mock = MockAudioService()
        mock.accountUser = "user@test.com"
        let vm = AccountViewModel(service: mock, state: state)

        vm.checkAccount()

        await yieldForTask()
        XCTAssertEqual(state.signedInUser, "user@test.com")
    }

    @MainActor
    func testCheckAccountNilDoesNotSetUser() async {
        let state = AppState()
        let mock = MockAudioService()
        mock.accountUser = nil
        let vm = AccountViewModel(service: mock, state: state)

        vm.checkAccount()

        await yieldForTask()
        XCTAssertNil(state.signedInUser)
    }

    // MARK: - Sources follow the account

    private let tuneIn = MusicSource(sid: 3, name: "TuneIn", type: "music_service", available: true)

    @MainActor
    func testSignInReloadsTheSources() async {
        let state = AppState()
        let mock = MockAudioService()
        mock.musicSources = [tuneIn]
        let vm = AccountViewModel(service: mock, state: state)

        vm.username = "user"
        vm.password = "pass"
        vm.signIn()
        await waitUntil { !state.musicSources.isEmpty }

        XCTAssertEqual(state.musicSources.map(\.sid), [3])
    }

    @MainActor
    func testSignOutReloadsTheSources() async {
        let state = AppState()
        state.signedInUser = "user"
        let mock = MockAudioService()
        mock.musicSources = [tuneIn]
        let vm = AccountViewModel(service: mock, state: state)

        vm.signOut()
        await waitUntil { !state.musicSources.isEmpty }

        XCTAssertTrue(mock.calls.contains("getMusicSources"))
    }

    @MainActor
    func testSignInKeepsAskingUntilAServiceIsAvailable() async {
        let state = AppState()
        let mock = MockAudioService()
        let notYet = MusicSource(sid: 3, name: "TuneIn", type: "music_service", available: false)
        mock.musicSources = [notYet]
        let vm = AccountViewModel(service: mock, state: state)

        vm.username = "user"
        vm.password = "pass"
        vm.signIn()
        await waitUntil { mock.calls.contains("getMusicSources") }
        mock.musicSources = [tuneIn]
        await waitUntil(timeout: 3) { state.musicSources.first?.available == true }

        XCTAssertEqual(mock.calls.filter { $0 == "getMusicSources" }.count, 2)
    }

    @MainActor
    func testFailedSignInShowsWhatTheSpeakerReportsAndReloadsTheSources() async {
        let state = AppState()
        state.signedInUser = "user"
        let mock = MockAudioService()
        mock.signInError = NSError(domain: "heos", code: 10, userInfo: [NSLocalizedDescriptionKey: "User not found"])
        mock.accountUser = nil
        mock.musicSources = [tuneIn]
        let vm = AccountViewModel(service: mock, state: state)

        vm.username = "nobody"
        vm.password = "wrong"
        vm.signIn()
        await waitUntil { mock.calls.contains("getMusicSources") }

        XCTAssertNil(state.signedInUser)
        XCTAssertTrue(mock.calls.contains("checkAccount"))
    }

    @MainActor
    func testRestoreSessionSkipsTheCredentialsThatJustFailed() async {
        let state = AppState()
        let mock = MockAudioService()
        mock.signInError = NSError(domain: "heos", code: 10, userInfo: [NSLocalizedDescriptionKey: "User not found"])
        let vm = AccountViewModel(service: mock, state: state)
        vm.rememberMe = true
        vm.username = "nobody"
        vm.password = "wrong"
        vm.signIn()
        await waitUntil { !vm.isSigningIn && mock.calls.contains("checkAccount") }

        vm.restoreSession()
        await yieldForTask()

        XCTAssertEqual(mock.calls.filter { $0.hasPrefix("signIn") }.count, 1)
    }

    // MARK: - restoreSession

    @MainActor
    func testRestoreSessionSignsInWithRememberedCredentials() async {
        let state = AppState()
        let mock = MockAudioService()
        let vm = AccountViewModel(service: mock, state: state)
        vm.rememberMe = true
        vm.username = "user"
        vm.password = "pass"

        vm.restoreSession()
        await waitUntil { state.signedInUser != nil }

        XCTAssertEqual(mock.calls.filter { $0 == "signIn:user" }.count, 1)
    }

    @MainActor
    func testRestoreSessionDoesNothingWithoutCredentials() async {
        let mock = MockAudioService()
        let vm = AccountViewModel(service: mock, state: AppState())

        vm.restoreSession()
        await yieldForTask()

        XCTAssertFalse(mock.calls.contains { $0.hasPrefix("signIn") })
    }

    @MainActor
    func testRestoreSessionDoesNothingWhenSignedIn() async {
        let state = AppState()
        state.signedInUser = "user"
        let mock = MockAudioService()
        let vm = AccountViewModel(service: mock, state: state)
        vm.username = "user"
        vm.password = "pass"

        vm.restoreSession()
        await yieldForTask()

        XCTAssertFalse(mock.calls.contains { $0.hasPrefix("signIn") })
    }

    @MainActor
    func testRestoreSessionDoesNothingWhenNotRemembered() async {
        let mock = MockAudioService()
        let vm = AccountViewModel(service: mock, state: AppState())
        vm.username = "user"
        vm.password = "pass"
        vm.rememberMe = false
        defer { vm.rememberMe = true }

        vm.restoreSession()
        await yieldForTask()

        XCTAssertFalse(mock.calls.contains { $0.hasPrefix("signIn") })
    }

    @MainActor
    func testReportedSignOutReachesTheListener() {
        let state = AppState()
        var reported: [String?] = []
        state.onAccountReported = { reported.append($0) }

        state.setSignedInUser("user")
        state.setSignedInUser(nil)

        XCTAssertEqual(reported, ["user", nil])
    }
}
