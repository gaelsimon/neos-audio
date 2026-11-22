import SwiftUI

/// The page for the place a browse model stands on, in the Mac window and in each iPhone and iPad page.
struct DestinationView: View {
    let state: AppState
    let container: ViewModelContainer
    let model: BrowseViewModel

    var body: some View {
        switch model.currentDestination {
        case .home:
            HomeView(state: state, homeVM: container.homeVM, browseVM: model)
        case .browse:
            BrowseContentView(state: state, browseVM: model)
        case .queue:
            QueueView(state: state, viewModel: container.queueVM, browseVM: model)
        case .settings:
            AccountSettingsView(
                state: state, accountVM: container.accountVM, settingsVM: container.settingsVM,
                homeVM: container.homeVM, localServersVM: container.localServersVM
            )
        case .ampSettings:
            AmpSettingsView(state: state, speakerVM: container.speakerVM, groupVM: container.groupVM)
        }
    }
}
