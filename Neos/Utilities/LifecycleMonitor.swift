import Foundation
import Network
import NeosDomain
#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// Sleep (macOS) or the background (iOS) suspends the session; otherwise the heartbeat needs ~45 s to notice.
@MainActor
final class LifecycleMonitor {
    #if os(macOS)
    nonisolated static let suspendNotification = NSWorkspace.willSleepNotification
    nonisolated static let resumeNotification = NSWorkspace.didWakeNotification
    nonisolated static var systemNotificationCenter: NotificationCenter { NSWorkspace.shared.notificationCenter }
    #else
    nonisolated static let suspendNotification = UIApplication.didEnterBackgroundNotification
    nonisolated static let resumeNotification = UIApplication.willEnterForegroundNotification
    nonisolated static var systemNotificationCenter: NotificationCenter { .default }
    #endif

    private let service: any ConnectionService
    private let state: AppState
    private let notificationCenter: NotificationCenter
    private let monitorsNetworkPath: Bool
    nonisolated(unsafe) private var observers: [NSObjectProtocol] = []
    nonisolated(unsafe) private var pathMonitor: NWPathMonitor?

    /// `monitorsNetworkPath` is off in tests: a live monitor fires on its own and fakes a pass.
    init(
        service: any ConnectionService,
        state: AppState,
        notificationCenter: NotificationCenter = LifecycleMonitor.systemNotificationCenter,
        monitorsNetworkPath: Bool = true
    ) {
        self.service = service
        self.state = state
        self.notificationCenter = notificationCenter
        self.monitorsNetworkPath = monitorsNetworkPath
    }

    func start() {
        guard observers.isEmpty else { return }
        observe(Self.suspendNotification) { service in await service.suspend() }
        observe(Self.resumeNotification) { service in await service.resume() }
        if monitorsNetworkPath { startPathMonitoring() }
    }

    func stop() {
        for observer in observers { notificationCenter.removeObserver(observer) }
        observers = []
        pathMonitor?.cancel()
        pathMonitor = nil
    }

    /// A usable network again: retry now if the session is down, ignore it if it never dropped.
    func handleNetworkPathSatisfied() {
        guard state.connectionState == .disconnected || state.connectionState == .reconnecting else { return }
        Task { [service] in await service.resume() }
    }

    private func startPathMonitoring() {
        let monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { path in
            guard path.status == .satisfied else { return }
            Task { @MainActor [weak self] in self?.handleNetworkPathSatisfied() }
        }
        monitor.start(queue: DispatchQueue(label: "com.galela.neos.path-monitor"))
        pathMonitor = monitor
    }

    private func observe(_ name: Notification.Name, action: @escaping @Sendable (any ConnectionService) async -> Void) {
        let observer = notificationCenter.addObserver(forName: name, object: nil, queue: .main) { [service] _ in
            Task { await action(service) }
        }
        observers.append(observer)
    }

    deinit {
        for observer in observers { notificationCenter.removeObserver(observer) }
        pathMonitor?.cancel()
    }
}
