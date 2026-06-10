import SwiftUI
import HEOSKit
import NeosDomain

@main
struct NeosApp: App {
    @State private var appState = AppState()
    @State private var service: HEOSService?
    @State private var container: ViewModelContainer?

    var body: some Scene {
        // Main app window
        WindowGroup {
            if let container {
                MainWindowView(
                    state: appState,
                    container: container
                )

            } else {
                VStack(spacing: DS.Spacing.md) {
                    Spinner(size: 24, lineWidth: 3)
                    Text("Initializing...")
                        .foregroundStyle(DS.Colors.textSecondary)
                }
                .frame(width: 600, height: 400)
                .onAppear {
                    initializeServices()
                }
            }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 700, height: 500)

        // Menu bar quick controls
        MenuBarExtra("Neos", systemImage: menuBarIcon) {
            if let container {
                MenuBarView(
                    state: appState,
                    playerVM: container.playerVM,
                    speakerVM: container.speakerVM
                )
            } else {
                VStack {
                    Spinner(size: 20, lineWidth: 2.5)
                    Text("Initializing...")
                        .typography(.secondary)
                }
                .frame(width: 280, height: 100)
            }
        }
        .menuBarExtraStyle(.window)
    }

    private var menuBarIcon: String {
        switch appState.connectionState {
        case .connected:
            DS.Icons.speakerFill
        case .connecting, .reconnecting:
            DS.Icons.speaker
        case .disconnected:
            DS.Icons.speaker
        }
    }

    private func initializeServices() {
        let isDemoMode = CommandLine.arguments.contains("--demo-mode")

        // Demo mode takes priority; always initialize even when hosted by XCTest
        if isDemoMode {
            let svc = DemoAudioService()
            let vms = ViewModelContainer(service: svc, state: appState)
            self.container = vms
            DemoDataProvider.populate(appState)
            return
        }

        // Keep unit tests hermetic: avoid real discovery/network startup when hosted by XCTest.
        let isUnitTestHost = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
            || NSClassFromString("XCTestCase") != nil
            || NSClassFromString("XCTestObservationCenter") != nil

        if isUnitTestHost {
            return
        }

        let skipDiscovery = CommandLine.arguments.contains("--skip-discovery")

        let svc = HEOSService(stateUpdater: appState)
        self.service = svc
        let vms = ViewModelContainer(service: svc, state: appState)
        self.container = vms

        // Skip network operations when running UI tests without a speaker
        if skipDiscovery {
            return
        }

        // Try cached device first, fall back to discovery
        if let cached = DeviceCache.load() {
            appState.connectionState = .connecting
            appState.connectedDevice = cached.device
            Task {
                do {
                    try await svc.connect(
                        host: cached.device.host,
                        port: cached.device.port,
                        cachedPlayerID: cached.selectedPlayerID
                    )
                    DeviceCache.save(device: cached.device, selectedPlayerID: appState.selectedPlayerID)
                } catch {
                    DeviceCache.clear()
                    appState.connectionState = .disconnected
                    vms.speakerVM.startContinuousDiscovery()
                }
            }
        } else {
            vms.speakerVM.startContinuousDiscovery()
        }
    }
}
