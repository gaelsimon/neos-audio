import Foundation
import NeosDomain

/// Atomically creates and holds every ViewModel the app needs.
///
/// Replaces the 10 separate `@State` optionals in `NeosApp`
/// with a single container that either exists (all VMs ready)
/// or is nil (still initializing).
///
/// ## Task Storage Pattern
///
/// View models store `Task` handles via `CancellableTaskHandle` (see `Neos/Utilities/`).
/// That helper wraps the `@ObservationIgnored nonisolated(unsafe)` storage required
/// because `Task` is not `Sendable`. It is safe because all VMs are `@MainActor`-isolated
/// and `Task.cancel()` is thread-safe; the helper cancels on `deinit`.
@MainActor
final class ViewModelContainer {
    let playerVM: PlayerViewModel
    let speakerVM: SpeakerListViewModel
    let queueVM: QueueViewModel
    let browseVM: BrowseViewModel
    let homeVM: HomeViewModel
    let accountVM: AccountViewModel
    let searchVM: SearchViewModel
    let queuePanelVM: QueuePanelViewModel
    let settingsVM: SettingsViewModel
    let groupVM: GroupViewModel
    let localServersVM: LocalServersViewModel
    private let service: any AudioService
    private let state: AppState
    private let serverPreferences: LocalServerPreferences

    init(service: any AudioService, state: AppState, localNetwork: LocalNetworkAccess? = nil) {
        self.service = service
        self.state = state
        self.playerVM = PlayerViewModel(service: service, state: state)
        self.speakerVM = SpeakerListViewModel(service: service, state: state, localNetwork: localNetwork)
        self.queueVM = QueueViewModel(service: service, state: state)
        let serverPreferences = LocalServerPreferences()
        self.serverPreferences = serverPreferences
        self.browseVM = BrowseViewModel(service: service, state: state, serverPreferences: serverPreferences)
        self.homeVM = HomeViewModel(service: service, state: state)
        self.accountVM = AccountViewModel(service: service, state: state)
        self.searchVM = SearchViewModel(service: service, state: state, serverPreferences: serverPreferences)
        self.queuePanelVM = QueuePanelViewModel(service: service, state: state)
        self.settingsVM = SettingsViewModel(state: state)
        self.groupVM = GroupViewModel(service: service, state: state)
        self.localServersVM = LocalServersViewModel(service: service, preferences: serverPreferences)

        playerVM.startTrackMetadataObserver()

        let home = homeVM
        accountVM.onAccountChanged = { [weak home] in home?.resetForAccountChange() }

        let account = accountVM
        state.onAccountReported = { [weak account] user in
            if user == nil { account?.restoreSession() }
        }

        let player = playerVM
        state.onTrackMetadataWanted = { [weak player] in player?.startTrackMetadataObserver() }

        let queue = queueVM
        state.onRadioStarted = { [weak queue] in queue?.removeLeftoverStreams() }

        let speakers = speakerVM
        state.onDeviceDiscovered = { [weak speakers] device in
            speakers?.autoConnectIfCached(device)
        }

        // Any navigation suspends an open search, not just the few that used to report one.
        let search = searchVM
        let browse = browseVM
        browseVM.onWillPushEntry = { [weak search, weak browse] in
            guard let search, let browse else { return }
            search.dropClosedByBack()
            guard search.isOverlayVisible else { return }
            search.suspendForNavigation(originToken: browse.currentHistoryToken)
        }
        // And it comes back on the entry it belongs to, whichever control moved there.
        browseVM.onDidMoveInHistory = { [weak search, weak browse] in
            guard let search, let browse else { return }
            search.tryRestore(atToken: browse.currentHistoryToken)
        }
    }

    /// A model for one page of the iPhone and iPad navigation, sharing the local server choices.
    func makeBrowseModel() -> BrowseViewModel {
        BrowseViewModel(service: service, state: state, serverPreferences: serverPreferences)
    }

    // MARK: - Navigation Commands

    /// Shared by the top bar arrows and the menu bar shortcuts.
    var canGoBack: Bool {
        searchVM.isOverlayVisible || searchVM.hasSuspendedSearch || browseVM.canGoBack
    }

    var canGoForward: Bool {
        searchVM.canReopen(atToken: browseVM.currentHistoryToken) || browseVM.canGoForward
    }

    func goBack() {
        if searchVM.isOverlayVisible {
            searchVM.closeForBack(atToken: browseVM.currentHistoryToken)
            return
        }
        browseVM.goBack()
    }

    func goForward() {
        if searchVM.reopen(atToken: browseVM.currentHistoryToken) { return }
        if searchVM.isOverlayVisible {
            searchVM.suspendForNavigation(originToken: browseVM.currentHistoryToken)
        }
        browseVM.goForward()
    }
}
