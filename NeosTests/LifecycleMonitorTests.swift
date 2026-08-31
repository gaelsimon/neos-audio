import XCTest
import AppKit
import NeosDomain
@testable import Neos

@MainActor
final class LifecycleMonitorTests: XCTestCase {

    private func makeMonitor(connectionState: ConnectionState = .connected)
        -> (LifecycleMonitor, MockAudioService, NotificationCenter, AppState) {
        let service = MockAudioService()
        let state = AppState()
        state.connectionState = connectionState
        let center = NotificationCenter()
        let monitor = LifecycleMonitor(
            service: service,
            state: state,
            notificationCenter: center,
            monitorsNetworkPath: false
        )
        monitor.start()
        return (monitor, service, center, state)
    }

    func testSleepSuspendsTheSession() async {
        let (monitor, service, center, _) = makeMonitor()
        defer { monitor.stop() }

        center.post(name: NSWorkspace.willSleepNotification, object: nil)
        await waitForCall("suspend", on: service)

        XCTAssertTrue(service.calls.contains("suspend"))
    }

    func testWakeResumesTheSession() async {
        let (monitor, service, center, _) = makeMonitor()
        defer { monitor.stop() }

        center.post(name: NSWorkspace.didWakeNotification, object: nil)
        await waitForCall("resume", on: service)

        XCTAssertTrue(service.calls.contains("resume"))
    }

    func testStopEndsObservation() async {
        let (monitor, service, center, _) = makeMonitor()
        monitor.stop()

        center.post(name: NSWorkspace.willSleepNotification, object: nil)
        await waitForCall("suspend", on: service)

        XCTAssertFalse(service.calls.contains("suspend"))
    }

    func testRestoredNetworkPathResumesAReconnectingSession() async {
        let (monitor, service, _, _) = makeMonitor(connectionState: .reconnecting)
        defer { monitor.stop() }

        monitor.handleNetworkPathSatisfied()
        await waitForCall("resume", on: service)

        XCTAssertTrue(service.calls.contains("resume"))
    }

    func testRestoredNetworkPathLeavesALiveSessionAlone() async {
        let (monitor, service, _, _) = makeMonitor(connectionState: .connected)
        defer { monitor.stop() }

        monitor.handleNetworkPathSatisfied()
        await waitForCall("resume", on: service)

        XCTAssertFalse(service.calls.contains("resume"))
    }

    /// The observer hands the call to a Task, so give it a few main-actor turns to land.
    private func waitForCall(_ call: String, on service: MockAudioService) async {
        for _ in 0..<50 {
            if service.calls.contains(call) { return }
            try? await Task.sleep(for: .milliseconds(10))
        }
    }
}
