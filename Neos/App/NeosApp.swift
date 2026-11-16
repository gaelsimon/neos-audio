import SwiftUI
import HEOSKit
import NeosDomain

@main
struct NeosApp: App {
    @State private var appState = AppState()
    @State private var service: HEOSService?
    @State private var container: ViewModelContainer?
    @State private var lifecycleMonitor: LifecycleMonitor?
    #if os(macOS)
    @State private var playbackKeyMonitor: PlaybackKeyMonitor?
    #endif
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            if let container {
                Group {
                    #if os(macOS)
                    MainWindowView(state: appState, container: container)
                    #else
                    MobileRootView(state: appState, container: container)
                    #endif
                }
                .onChange(of: scenePhase) { _, phase in
                    guard phase == .active else { return }
                    // Recover any playback events missed while the window was inactive.
                    container.playerVM.resyncPlaybackState()
                    container.speakerVM.retryIfLocalNetworkWasDenied()
                }

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
        #if os(macOS)
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1280, height: 800)
        .commands { AppCommands(state: appState, container: container) }
        #endif

        #if os(macOS)
        MenuBarExtra {
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
                .background(DS.Colors.background)
                .preferredColorScheme(.dark)
                .onAppear { initializeServices() }
            }
        } label: {
            // The status item renders at launch, so this boots the app even with no window.
            Image(nsImage: menuBarIcon)
                .onAppear { initializeServices() }
        }
        .menuBarExtraStyle(.window)
        #endif
    }

    #if os(macOS)
    private var menuBarIcon: NSImage {
        menuBarVinyl(connectionState: appState.connectionState, isPlaying: appState.isPlaying).image()
    }

    /// Space and ⌘ with an arrow go through a key monitor, which reads the first responder as the key lands.
    private func installPlaybackKeyMonitor(for vms: ViewModelContainer) {
        let monitor = PlaybackKeyMonitor(state: appState) { vms.playerVM.togglePlayPause() }
        monitor.start()
        self.playbackKeyMonitor = monitor
    }
    #else
    private func installPlaybackKeyMonitor(for _: ViewModelContainer) {
        // iOS has neither a menu bar nor a key monitor to install.
    }
    #endif

    /// Idempotent: whichever scene appears first boots the services.
    private func initializeServices() {
        guard container == nil else { return }

        // Debug only, and ahead of the XCTest check: the demo initialises even under tests.
        #if DEBUG
        if DemoSession.isActive {
            let svc = DemoAudioService(state: appState)
            let vms = ViewModelContainer(service: svc, state: appState)
            self.container = vms
            installPlaybackKeyMonitor(for: vms)
            DemoDataProvider.populate(appState)
            return
        }
        #endif

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
        let vms = ViewModelContainer(service: svc, state: appState, localNetwork: LocalNetworkAccess())
        self.container = vms

        let monitor = LifecycleMonitor(service: svc, state: appState)
        monitor.start()
        self.lifecycleMonitor = monitor

        installPlaybackKeyMonitor(for: vms)

        // Skip network operations when running UI tests without a speaker
        if skipDiscovery {
            return
        }

        // Discovery runs alongside the cached connection, so a speaker on a new IP is still found
        vms.speakerVM.startContinuousDiscovery()

        if let cached = DeviceCache.load() {
            vms.speakerVM.connectToCachedDevice(cached)
        }

        // The App Store updates its own build.
        #if !APP_STORE
        startUpdateCheck()
        #endif
    }

    private func startUpdateCheck() {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        let checker = UpdateChecker(currentVersion: version)
        let state = appState
        Task { @MainActor in
            guard let update = await checker.check() else { return }
            state.availableUpdate = update
            if checker.markNotified(update) {
                state.showToast("Neos \(update.version) is available", icon: DS.Icons.update, style: .info)
            }
        }
    }
}
