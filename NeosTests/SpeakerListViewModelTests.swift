import XCTest
import Network
import dnssd
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

    // MARK: - connectToCachedDevice

    @MainActor
    func testCachedConnectRetriesAfterATransientFailure() async {
        let device = DiscoveredDevice(host: "192.168.1.10", friendlyName: "Living Room")
        DeviceCache.save(device: device, selectedPlayerID: 7)
        defer { DeviceCache.clear() }
        let state = AppState()
        let mock = MockAudioService()
        mock.failingConnectAttempts = 1
        let vm = SpeakerListViewModel(service: mock, state: state)

        vm.connectToCachedDevice(CachedDevice(device: device, selectedPlayerID: 7), retryDelays: [.milliseconds(10), .milliseconds(10)])

        try? await Task.sleep(for: .milliseconds(120))
        XCTAssertEqual(mock.calls.filter { $0 == "connect" }.count, 2)
        XCTAssertNotNil(DeviceCache.load())
    }

    @MainActor
    func testACachedConnectRefusedAtLaunchIsRetriedWithinASecond() async {
        let device = DiscoveredDevice(host: "192.168.1.10", friendlyName: "Living Room")
        DeviceCache.save(device: device, selectedPlayerID: 7)
        defer { DeviceCache.clear() }
        let mock = MockAudioService()
        mock.failingConnectAttempts = 1
        let vm = SpeakerListViewModel(service: mock, state: AppState())

        vm.connectToCachedDevice(CachedDevice(device: device, selectedPlayerID: 7))

        try? await Task.sleep(for: .milliseconds(900))
        XCTAssertEqual(mock.calls.filter { $0 == "connect" }.count, 2)
    }

    @MainActor
    func testCachedConnectKeepsTheDeviceWhenEveryAttemptFails() async {
        let device = DiscoveredDevice(host: "192.168.1.10", friendlyName: "Living Room")
        DeviceCache.save(device: device, selectedPlayerID: 7)
        defer { DeviceCache.clear() }
        let state = AppState()
        let mock = MockAudioService()
        mock.connectError = NSError(domain: "test", code: 1)
        let vm = SpeakerListViewModel(service: mock, state: state)

        vm.connectToCachedDevice(CachedDevice(device: device, selectedPlayerID: 7), retryDelays: [.milliseconds(10), .milliseconds(10)])

        try? await Task.sleep(for: .milliseconds(150))
        XCTAssertEqual(mock.calls.filter { $0 == "connect" }.count, 3)
        XCTAssertEqual(state.connectionState, .disconnected)
        XCTAssertNotNil(DeviceCache.load())
    }

    /// A speaker that accepts TCP but never answers the CLI publishes `.connected` before the
    /// session exists; giving up must clear it, or discovery stays behind a dead banner.
    @MainActor
    func testFailedCachedConnectEndsTheEstablishedSession() async {
        let device = DiscoveredDevice(host: "192.168.1.10", friendlyName: "Living Room")
        DeviceCache.save(device: device, selectedPlayerID: 7)
        defer { DeviceCache.clear() }
        let state = AppState()
        state.setConnectionState(.connected)
        let mock = MockAudioService()
        mock.connectError = NSError(domain: "test", code: 1)
        let vm = SpeakerListViewModel(service: mock, state: state)

        vm.connectToCachedDevice(CachedDevice(device: device, selectedPlayerID: 7), retryDelays: [.milliseconds(10), .milliseconds(10)])

        try? await Task.sleep(for: .milliseconds(150))
        XCTAssertEqual(state.connectionState, .disconnected)
        XCTAssertFalse(state.hasEstablishedSession)
    }

    // MARK: - autoConnectIfCached

    @MainActor
    func testRediscoveredSpeakerReconnectsOnItsOwnAndUpdatesTheAddress() async {
        let cached = DiscoveredDevice(host: "192.168.1.10", friendlyName: "Living Room", serialNumber: "S1")
        DeviceCache.save(device: cached, selectedPlayerID: 7)
        defer { DeviceCache.clear() }
        let state = AppState()
        let mock = MockAudioService()
        let vm = SpeakerListViewModel(service: mock, state: state)

        vm.autoConnectIfCached(DiscoveredDevice(host: "192.168.1.42", friendlyName: "Living Room", serialNumber: "S1"))

        await yieldForTask()
        XCTAssertTrue(mock.calls.contains("connect"))
        XCTAssertEqual(DeviceCache.load()?.device.host, "192.168.1.42")
    }

    @MainActor
    func testAnUnknownSpeakerIsNotConnectedTo() async {
        DeviceCache.save(device: DiscoveredDevice(host: "192.168.1.10", serialNumber: "S1"), selectedPlayerID: nil)
        defer { DeviceCache.clear() }
        let state = AppState()
        let mock = MockAudioService()
        let vm = SpeakerListViewModel(service: mock, state: state)

        vm.autoConnectIfCached(DiscoveredDevice(host: "192.168.1.99", serialNumber: "S2"))

        await yieldForTask()
        XCTAssertFalse(mock.calls.contains("connect"))
    }

    @MainActor
    func testALiveConnectionIsNotInterrupted() async {
        let cached = DiscoveredDevice(host: "192.168.1.10", serialNumber: "S1")
        DeviceCache.save(device: cached, selectedPlayerID: nil)
        defer { DeviceCache.clear() }
        let state = AppState()
        state.connectionState = .connected
        let mock = MockAudioService()
        let vm = SpeakerListViewModel(service: mock, state: state)

        vm.autoConnectIfCached(cached)

        await yieldForTask()
        XCTAssertFalse(mock.calls.contains("connect"))
    }

    // MARK: - startContinuousDiscovery

    @MainActor
    func testContinuousDiscoveryKeepsSayingItIsSearchingUntilItGivesUp() async {
        let state = AppState()
        let mock = MockAudioService()
        let vm = SpeakerListViewModel(service: mock, state: state)

        vm.startContinuousDiscovery(giveUpAfter: .milliseconds(200))

        XCTAssertTrue(state.isDiscovering)
        try? await Task.sleep(for: .milliseconds(80))
        XCTAssertTrue(state.isDiscovering)

        try? await Task.sleep(for: .milliseconds(250))
        XCTAssertFalse(state.isDiscovering)
    }

    // MARK: - Local network permission

    private static let refusal = NWBrowser.State.waiting(.dns(DNSServiceErrorType(kDNSServiceErr_PolicyDenied)))

    @MainActor
    func testEachSearchAsksWhetherTheLocalNetworkIsAllowed() {
        var checks = 0
        let access = LocalNetworkAccess(probe: { _ in
            checks += 1
            return {}
        })
        let vm = SpeakerListViewModel(service: MockAudioService(), state: AppState(), localNetwork: access)

        vm.discover()
        vm.startContinuousDiscovery(giveUpAfter: .milliseconds(10))

        XCTAssertEqual(checks, 2)
    }

    @MainActor
    func testARefusedLocalNetworkShowsOnTheViewModel() {
        let access = LocalNetworkAccess(probe: { _ in {} })
        let vm = SpeakerListViewModel(service: MockAudioService(), state: AppState(), localNetwork: access)
        XCTAssertFalse(vm.isLocalNetworkDenied)

        access.apply(Self.refusal)

        XCTAssertTrue(vm.isLocalNetworkDenied)
    }

    @MainActor
    func testThePermissionComingBackStartsASearch() {
        let state = AppState()
        let access = LocalNetworkAccess(probe: { _ in {} })
        let vm = SpeakerListViewModel(service: MockAudioService(), state: state, localNetwork: access)
        access.apply(Self.refusal)
        XCTAssertFalse(state.isDiscovering)

        access.apply(.ready)

        XCTAssertTrue(state.isDiscovering)
        XCTAssertFalse(vm.isLocalNetworkDenied)
    }

    @MainActor
    func testComingBackToTheAppSearchesAgainOnlyAfterARefusal() {
        let state = AppState()
        let access = LocalNetworkAccess(probe: { _ in {} })
        let vm = SpeakerListViewModel(service: MockAudioService(), state: state, localNetwork: access)

        vm.retryIfLocalNetworkWasDenied()
        XCTAssertFalse(state.isDiscovering)

        access.apply(Self.refusal)
        vm.retryIfLocalNetworkWasDenied()
        XCTAssertTrue(state.isDiscovering)
    }

    @MainActor
    func testWithoutACheckTheLocalNetworkIsNeverSaidRefused() {
        let vm = SpeakerListViewModel(service: MockAudioService(), state: AppState())

        vm.discover()

        XCTAssertFalse(vm.isLocalNetworkDenied)
    }
}
