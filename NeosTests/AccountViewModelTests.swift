import XCTest
@testable import Neos
import NeosDomain

final class AccountViewModelTests: XCTestCase {

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
}
