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
    }
}
