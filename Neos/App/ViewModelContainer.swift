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

    init(service: any AudioService, state: AppState) {
        self.playerVM = PlayerViewModel(service: service, state: state)
        self.speakerVM = SpeakerListViewModel(service: service, state: state)
        self.queueVM = QueueViewModel(service: service, state: state)
        self.browseVM = BrowseViewModel(service: service, state: state)
        self.homeVM = HomeViewModel(service: service, state: state)
        self.accountVM = AccountViewModel(service: service, state: state)
        self.searchVM = SearchViewModel(service: service, state: state)
        self.queuePanelVM = QueuePanelViewModel(service: service, state: state)
        self.settingsVM = SettingsViewModel(state: state)
        self.groupVM = GroupViewModel(service: service, state: state)

        playerVM.startTrackMetadataObserver()

        let speakers = speakerVM
        state.onDeviceDiscovered = { [weak speakers] device in
            speakers?.autoConnectIfCached(device)
        }

        // Any navigation suspends an open search, not just the few that used to report one.
        let search = searchVM
        let browse = browseVM
        browseVM.onWillPushEntry = { [weak search, weak browse] in
            guard let search, let browse, search.isOverlayVisible else { return }
            search.suspendForNavigation(originToken: browse.currentHistoryToken)
        }
        // And it comes back on the entry it belongs to, whichever control moved there.
        browseVM.onDidMoveInHistory = { [weak search, weak browse] in
            guard let search, let browse else { return }
            search.tryRestore(atToken: browse.currentHistoryToken)
        }
    }

    // MARK: - Navigation Commands

    /// Shared by the top bar arrows and the menu bar shortcuts.
    var canGoBack: Bool {
        searchVM.isOverlayVisible || searchVM.hasSuspendedSearch || browseVM.canGoBack
    }

    var canGoForward: Bool { browseVM.canGoForward }

    func goBack() {
        if searchVM.isOverlayVisible {
            searchVM.dismissOverlay()
            return
        }
        browseVM.goBack()
    }

    func goForward() {
        if searchVM.isOverlayVisible {
            searchVM.suspendForNavigation(originToken: browseVM.currentHistoryToken)
        }
        browseVM.goForward()
    }
}
