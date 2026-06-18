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

    init(service: any AudioService, state: AppState) {
        self.service = service
        self.state = state
    }

    func selectPlayer(_ player: Player) {
        state.selectedPlayerID = state.groups.leaderPID(for: player.pid)
    }

    func discover() {
        let requestID = discoveryTracker.next()
        state.isDiscovering = true
        state.discoveryError = nil
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

    func startContinuousDiscovery() {
        let requestID = discoveryTracker.next()
        state.isDiscovering = true
        state.discoveryError = nil
        continuousDiscoveryTask.replace(with: Task {
            service.startContinuousDiscovery()
            // Mark initial burst as complete after a short delay
            try? await Task.sleep(for: .seconds(3))
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

    func connectToDevice(_ device: DiscoveredDevice) {
        state.connectionState = .connecting
        connectTask.replace(with: Task {
            do {
                try await service.connect(host: device.host, port: device.port)
                guard !Task.isCancelled else { return }
                stopContinuousDiscovery()
                state.connectedDevice = device
                DeviceCache.save(device: device, selectedPlayerID: state.selectedPlayerID)
            } catch {
                guard !Task.isCancelled else { return }
                state.connectedDevice = nil
                state.error = .connectionFailed("Failed to connect: \(error.localizedDescription)")
                state.connectionState = .disconnected
            }
        })
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
                state.connectionState = .disconnected
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
