import Foundation
import NeosDomain

@Observable
@MainActor
final class SpeakerListViewModel {
    private let service: any AudioService
    private let state: AppState

    var manualHost: String = ""
    private let discoveryTask = CancellableTaskHandle()
    private let continuousDiscoveryTask = CancellableTaskHandle()
    private let connectTask = CancellableTaskHandle()
    private let powerTask = CancellableTaskHandle()
    private let discoveryTracker = RequestTracker()
    private let localNetwork: LocalNetworkAccess?

    var isLocalNetworkDenied: Bool { localNetwork?.isDenied ?? false }

    init(service: any AudioService, state: AppState, localNetwork: LocalNetworkAccess? = nil) {
        self.service = service
        self.state = state
        self.localNetwork = localNetwork
        localNetwork?.onAllowedAgain = { [weak self] in self?.discover() }
    }

    /// Back in the app, perhaps from the system's settings where the permission was just given.
    func retryIfLocalNetworkWasDenied() {
        guard isLocalNetworkDenied else { return }
        discover()
    }

    func selectPlayer(_ player: Player) {
        state.selectedPlayerID = state.groups.leaderPID(for: player.pid, expanded: state.multiRoomGroupIDs)
    }

    func discover() {
        let requestID = discoveryTracker.next()
        state.isDiscovering = true
        state.discoveryError = nil
        localNetwork?.check()
        discoveryTask.replace(with: Task {
            do {
                let devices = try await service.discoverDevices()
                guard discoveryTracker.isCurrent(requestID), !Task.isCancelled else { return }
                state.discoveredDevices = devices
            } catch {
                guard discoveryTracker.isCurrent(requestID), !Task.isCancelled else { return }
                state.discoveryError = "Discovery failed: \(error.localizedDescription)"
            }
            guard discoveryTracker.isCurrent(requestID), !Task.isCancelled else { return }
            state.isDiscovering = false
        })
    }

    /// The search keeps running; `giveUpAfter` is only how long the UI says so (SSDP alone takes 5 s).
    func startContinuousDiscovery(giveUpAfter timeout: Duration = .seconds(10)) {
        let requestID = discoveryTracker.next()
        state.isDiscovering = true
        state.discoveryError = nil
        localNetwork?.check()
        continuousDiscoveryTask.replace(with: Task {
            service.startContinuousDiscovery()
            try? await Task.sleep(for: timeout)
            guard discoveryTracker.isCurrent(requestID), !Task.isCancelled else { return }
            state.isDiscovering = false
        })
    }

    func stopContinuousDiscovery() {
        state.isDiscovering = false
        continuousDiscoveryTask.cancel()
        Task {
            await service.stopContinuousDiscovery()
        }
    }

    func connectToDevice(_ device: DiscoveredDevice, cachedPlayerID: Int? = nil) {
        state.connectionState = .connecting
        connectTask.replace(with: Task {
            do {
                try await service.connect(host: device.host, port: device.port, cachedPlayerID: cachedPlayerID)
                guard !Task.isCancelled else { return }
                stopContinuousDiscovery()
                state.connectedDevice = device
                DeviceCache.save(device: device, selectedPlayerID: state.selectedPlayerID)
            } catch {
                guard !Task.isCancelled else { return }
                state.connectedDevice = nil
                state.error = .connectionFailed("Failed to connect: \(error.localizedDescription)")
                state.setConnectionState(.disconnected)
            }
        })
    }

    /// A new build's first connect is refused while macOS checks local network access, so the first retry comes soon.
    static let cachedConnectRetryDelays: [Duration] = [.milliseconds(500), .seconds(2), .seconds(2)]

    /// A booting speaker or a late Wi-Fi must not make the app forget it: keep the cache and retry.
    func connectToCachedDevice(_ cached: CachedDevice, retryDelays: [Duration] = SpeakerListViewModel.cachedConnectRetryDelays) {
        state.connectionState = .connecting
        state.connectedDevice = cached.device
        connectTask.replace(with: Task {
            for attempt in 0...retryDelays.count {
                do {
                    try await service.connect(
                        host: cached.device.host,
                        port: cached.device.port,
                        cachedPlayerID: cached.selectedPlayerID
                    )
                    guard !Task.isCancelled else { return }
                    stopContinuousDiscovery()
                    DeviceCache.save(device: cached.device, selectedPlayerID: state.selectedPlayerID)
                    return
                } catch {
                    guard !Task.isCancelled else { return }
                    if attempt < retryDelays.count {
                        try? await Task.sleep(for: retryDelays[attempt])
                        guard !Task.isCancelled else { return }
                    }
                }
            }
            // The cache is kept for the auto-reconnect, but nothing is connected any more.
            state.connectedDevice = nil
            state.setConnectionState(.disconnected)
        })
    }

    /// A remembered speaker reappearing reconnects without a click, on whatever address it now has.
    func autoConnectIfCached(_ device: DiscoveredDevice) {
        guard state.connectionState == .disconnected,
              let cached = DeviceCache.load(),
              cached.matches(device) else { return }
        connectToDevice(device, cachedPlayerID: cached.selectedPlayerID)
    }

    func connectManual(host: String) {
        let trimmed = host.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        state.connectionState = .connecting
        connectTask.replace(with: Task {
            do {
                try await service.connect(host: trimmed, port: 1255)
                guard !Task.isCancelled else { return }
                stopContinuousDiscovery()
                let device = DiscoveredDevice(host: trimmed, friendlyName: trimmed)
                state.connectedDevice = device
                DeviceCache.save(device: device, selectedPlayerID: state.selectedPlayerID)
            } catch {
                guard !Task.isCancelled else { return }
                state.connectedDevice = nil
                state.error = .connectionFailed("Failed to connect to \(trimmed): \(error.localizedDescription)")
                state.setConnectionState(.disconnected)
            }
        })
    }

    func disconnect() {
        connectTask.cancel()
        DeviceCache.clear()
        Task {
            await service.disconnect()
            state.connectedDevice = nil
            startContinuousDiscovery()
        }
    }

    func togglePower() {
        let wasOn = state.isPoweredOn
        state.isPoweredOn = !wasOn
        powerTask.replace(with: Task {
            do {
                if wasOn {
                    try await service.powerOff()
                } else {
                    try await service.powerOn()
                }
            } catch {
                guard !Task.isCancelled else { return }
                state.isPoweredOn = wasOn
                state.error = .powerFailed("Power control failed: \(error.localizedDescription)")
            }
        })
    }
}
