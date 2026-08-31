import XCTest
@testable import Neos

/// Stand-in for the system login-item service so tests never register a real login item.
private final class MockLoginItemService: LoginItemService {
    var isEnabled = false
    var requiresApproval = false
    var registerError: Error?
    var unregisterError: Error?
    private(set) var calls: [String] = []

    func register() throws {
        calls.append("register")
        if let registerError { throw registerError }
        isEnabled = true
    }

    func unregister() throws {
        calls.append("unregister")
        if let unregisterError { throw unregisterError }
        isEnabled = false
    }
}

final class SettingsViewModelTests: XCTestCase {

    @MainActor
    func testLaunchAtLoginReflectsInitialStatus() {
        let loginItem = MockLoginItemService()
        loginItem.isEnabled = true

        let vm = SettingsViewModel(state: AppState(), loginItem: loginItem)

        XCTAssertTrue(vm.launchAtLoginEnabled)
    }

    @MainActor
    func testEnablingLaunchAtLoginRegisters() {
        let loginItem = MockLoginItemService()
        let vm = SettingsViewModel(state: AppState(), loginItem: loginItem)

        vm.setLaunchAtLogin(true)

        XCTAssertEqual(loginItem.calls, ["register"])
        XCTAssertTrue(vm.launchAtLoginEnabled)
    }

    @MainActor
    func testDisablingLaunchAtLoginUnregisters() {
        let loginItem = MockLoginItemService()
        loginItem.isEnabled = true
        let vm = SettingsViewModel(state: AppState(), loginItem: loginItem)

        vm.setLaunchAtLogin(false)

        XCTAssertEqual(loginItem.calls, ["unregister"])
        XCTAssertFalse(vm.launchAtLoginEnabled)
    }

    @MainActor
    func testFailedRegistrationKeepsToggleOffAndWarns() {
        let state = AppState()
        let loginItem = MockLoginItemService()
        loginItem.registerError = NSError(domain: "test", code: 1)
        let vm = SettingsViewModel(state: state, loginItem: loginItem)

        vm.setLaunchAtLogin(true)

        XCTAssertFalse(vm.launchAtLoginEnabled)
        XCTAssertNotNil(state.toast)
    }

    @MainActor
    func testPendingApprovalIsSurfaced() {
        let loginItem = MockLoginItemService()
        loginItem.requiresApproval = true

        let vm = SettingsViewModel(state: AppState(), loginItem: loginItem)

        XCTAssertTrue(vm.launchAtLoginNeedsApproval)
    }
}
