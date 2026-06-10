import XCTest
@testable import Neos
import NeosDomain

final class SpeakerListViewModelTests: XCTestCase {

    // MARK: - selectPlayer

    @MainActor
    func testSelectPlayerSetsSelectedPlayerID() {
        let state = AppState()
        let mock = MockAudioService()
        let vm = SpeakerListViewModel(service: mock, state: state)

        let player = Player(pid: 42, name: "Office")
        vm.selectPlayer(player)

        XCTAssertEqual(state.selectedPlayerID, 42)
    }

    // MARK: - discover

    @MainActor
    func testDiscoverSetsDiscoveringFlag() {
        let state = AppState()
        let mock = MockAudioService()
        let vm = SpeakerListViewModel(service: mock, state: state)

        vm.discover()

        XCTAssertTrue(state.isDiscovering)
        XCTAssertNil(state.discoveryError)
    }

    @MainActor
    func testDiscoverPopulatesDevices() async {
        let state = AppState()
        let mock = MockAudioService()
        mock.discoveredDevicesList = [
            DiscoveredDevice(host: "192.168.1.10", friendlyName: "Living Room")
        ]
        let vm = SpeakerListViewModel(service: mock, state: state)

        vm.discover()

        await yieldForTask()
        XCTAssertEqual(state.discoveredDevices.count, 1)
        XCTAssertEqual(state.discoveredDevices[0].friendlyName, "Living Room")
        XCTAssertFalse(state.isDiscovering)
    }

    @MainActor
    func testDiscoverErrorSetsDiscoveryError() async {
        let state = AppState()
        let mock = MockAudioService()
        mock.discoverError = NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "No response"])
        let vm = SpeakerListViewModel(service: mock, state: state)

        vm.discover()

        await yieldForTask()
        XCTAssertNotNil(state.discoveryError)
        XCTAssertFalse(state.isDiscovering)
    }

    // MARK: - connectToDevice

    @MainActor
    func testConnectToDeviceSetsConnectingState() {
        let state = AppState()
        let mock = MockAudioService()
        let vm = SpeakerListViewModel(service: mock, state: state)

        let device = DiscoveredDevice(host: "192.168.1.10")
        vm.connectToDevice(device)

        XCTAssertEqual(state.connectionState, .connecting)
    }

    @MainActor
    func testConnectToDeviceSuccessSetsConnectedDevice() async {
        let state = AppState()
        let mock = MockAudioService()
        let vm = SpeakerListViewModel(service: mock, state: state)

        let device = DiscoveredDevice(host: "192.168.1.10", friendlyName: "Kitchen")
        vm.connectToDevice(device)

        await yieldForTask()
        XCTAssertEqual(state.connectedDevice?.host, "192.168.1.10")
    }

    @MainActor
    func testConnectToDeviceFailureSetsError() async {
        let state = AppState()
        let mock = MockAudioService()
        mock.connectError = NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Refused"])
        let vm = SpeakerListViewModel(service: mock, state: state)

        let device = DiscoveredDevice(host: "192.168.1.10")
        vm.connectToDevice(device)

        await yieldForTask()
        XCTAssertNil(state.connectedDevice)
        XCTAssertNotNil(state.error)
        XCTAssertEqual(state.connectionState, .disconnected)
    }

    // MARK: - connectManual

    @MainActor
    func testConnectManualGuardsEmptyHost() {
        let state = AppState()
        let mock = MockAudioService()
        let vm = SpeakerListViewModel(service: mock, state: state)

        vm.connectManual(host: "   ")

        // Should not change state
        XCTAssertEqual(state.connectionState, .disconnected)
    }

    @MainActor
    func testConnectManualTrimsWhitespace() async {
        let state = AppState()
        let mock = MockAudioService()
        let vm = SpeakerListViewModel(service: mock, state: state)

        vm.connectManual(host: "  192.168.1.5  ")

        await yieldForTask()
        XCTAssertEqual(state.connectedDevice?.host, "192.168.1.5")
    }

    // MARK: - disconnect

    @MainActor
    func testDisconnectClearsCache() async {
        let state = AppState()
        let mock = MockAudioService()
        let vm = SpeakerListViewModel(service: mock, state: state)

        // Pre-set connected device
        let device = DiscoveredDevice(host: "192.168.1.10")
        state.connectedDevice = device
        DeviceCache.save(device: device, selectedPlayerID: 1)

        vm.disconnect()

        await yieldForTask()
        XCTAssertNil(state.connectedDevice)
        XCTAssertNil(DeviceCache.load())
    }

    // MARK: - togglePower

    @MainActor
    func testTogglePowerOptimisticallyToggles() {
        let state = AppState()
        state.isPoweredOn = true
        let mock = MockAudioService()
        let vm = SpeakerListViewModel(service: mock, state: state)

        vm.togglePower()

        XCTAssertFalse(state.isPoweredOn)
    }

    @MainActor
    func testTogglePowerOnWhenOff() {
        let state = AppState()
        state.isPoweredOn = false
        let mock = MockAudioService()
        let vm = SpeakerListViewModel(service: mock, state: state)

        vm.togglePower()

        XCTAssertTrue(state.isPoweredOn)
    }

    @MainActor
    func testTogglePowerCallsCorrectService() async {
        let state = AppState()
        state.isPoweredOn = true
        let mock = MockAudioService()
        let vm = SpeakerListViewModel(service: mock, state: state)

        vm.togglePower()

        await yieldForTask()
        XCTAssertTrue(mock.calls.contains("powerOff"))
    }

    @MainActor
    func testTogglePowerRevertsOnError() async {
        let state = AppState()
        state.isPoweredOn = true
        let mock = MockAudioService()
        mock.powerOffError = NSError(domain: "test", code: 1)
        let vm = SpeakerListViewModel(service: mock, state: state)

        vm.togglePower()
        XCTAssertFalse(state.isPoweredOn)

        await yieldForTask()
        XCTAssertTrue(state.isPoweredOn)
        XCTAssertNotNil(state.error)
    }
}
