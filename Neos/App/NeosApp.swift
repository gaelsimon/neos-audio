import SwiftUI
import HEOSKit
import NeosDomain

@main
struct NeosApp: App {
    @State private var appState = AppState()
    @State private var service: HEOSService?
    @State private var container: ViewModelContainer?
    @State private var lifecycleMonitor: LifecycleMonitor?
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        // Main app window
        WindowGroup {
            if let container {
                MainWindowView(
                    state: appState,
                    container: container
                )
                .onChange(of: scenePhase) { _, phase in
                    // Recover any playback events missed while the window was inactive.
                    if phase == .active { container.playerVM.resyncPlaybackState() }
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
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 700, height: 500)
        .commands { playbackCommands }

        // Menu bar quick controls
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
            Image(systemName: menuBarIcon)
                .onAppear { initializeServices() }
        }
        .menuBarExtraStyle(.window)
    }

    // MARK: - Menu Commands

    /// Space stays disabled while the search field has focus so the key reaches the text field.
    @CommandsBuilder
    private var playbackCommands: some Commands {
        CommandMenu("Playback") {
            Button(appState.isPlaying ? "Pause" : "Play") {
                container?.playerVM.togglePlayPause()
            }
            .keyboardShortcut(.space, modifiers: [])
            .disabled(container == nil || !appState.isConnected || appState.isSearchFieldFocused)

            Divider()

            Button("Back") { container?.goBack() }
                .keyboardShortcut("[", modifiers: .command)
                .disabled(container?.canGoBack != true)

            Button("Forward") { container?.goForward() }
                .keyboardShortcut("]", modifiers: .command)
                .disabled(container?.canGoForward != true)

            Divider()

            Button("Search") { appState.isSearchFieldFocused = true }
                .keyboardShortcut("f", modifiers: .command)
                .disabled(container == nil || !appState.isConnected)

            Button(appState.isNowPlayingCanvasOpen ? "Exit Full Screen Player" : "Full Screen Player") {
                appState.isNowPlayingCanvasOpen.toggle()
            }
            .keyboardShortcut("f", modifiers: [.command, .shift])
            .disabled(container == nil || !appState.isConnected)
        }
    }

    private var menuBarIcon: String {
        menuBarIconName(connectionState: appState.connectionState, isPlaying: appState.isPlaying)
    }

    /// Idempotent: whichever scene appears first boots the services.
    private func initializeServices() {
        guard container == nil else { return }
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

        let monitor = LifecycleMonitor(service: svc, state: appState)
        monitor.start()
        self.lifecycleMonitor = monitor

        // Skip network operations when running UI tests without a speaker
        if skipDiscovery {
            return
        }

        // Discovery runs alongside the cached connection, so a speaker on a new IP is still found
        vms.speakerVM.startContinuousDiscovery()

        if let cached = DeviceCache.load() {
            vms.speakerVM.connectToCachedDevice(cached)
        }
    }
}
