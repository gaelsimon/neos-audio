import AppKit
import Network
import NeosDomain

/// Sleep suspends the session and wake resumes it; otherwise the heartbeat needs ~45 s to notice.
@MainActor
final class LifecycleMonitor {
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
        notificationCenter: NotificationCenter = NSWorkspace.shared.notificationCenter,
        monitorsNetworkPath: Bool = true
    ) {
        self.service = service
        self.state = state
        self.notificationCenter = notificationCenter
        self.monitorsNetworkPath = monitorsNetworkPath
    }

    func start() {
        guard observers.isEmpty else { return }
        observe(NSWorkspace.willSleepNotification) { service in await service.suspend() }
        observe(NSWorkspace.didWakeNotification) { service in await service.resume() }
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
