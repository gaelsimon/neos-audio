import SwiftUI
import NeosDomain

/// The sources as a list, where the Mac has its sidebar.
struct LibraryView: View {
    let state: AppState
    let container: ViewModelContainer
    let model: BrowseViewModel

    var body: some View {
        let sections = SourceSections(
            sources: state.musicSources,
            signedIn: state.signedInUser != nil,
            hidden: container.homeVM.hiddenSIDs
        )

        List {
            Section {
                ForEach(sections.library) { entry in
                    row { model.selectSource(entry.source) } label: {
                        Label(entry.title, systemImage: entry.symbol)
                    }
                }
                row { model.selectQueue() } label: {
                    Label("Queue", systemImage: DS.Icons.queue)
                }
            }
            if !sections.services.isEmpty {
                Section("Services") {
                    ForEach(sections.services) { sourceRow($0) }
                }
            }
            if !sections.local.isEmpty {
                Section("Local") {
                    ForEach(sections.local) { sourceRow($0) }
                }
            }
        }
        .navigationTitle("Library")
    }

    private func sourceRow(_ source: MusicSource) -> some View {
        row { model.selectSource(source) } label: {
            Label {
                Text(source.name)
            } icon: {
                ServiceBranding.serviceIcon(for: source, size: 28)
            }
        }
        // Signed out, the speaker marks every service unavailable, TuneIn included; the page says why.
        .opacity(source.available ? 1 : 0.6)
    }

    /// Every row opens a page, so it carries the chevron a `NavigationLink` would draw.
    private func row<Content: View>(action: @escaping () -> Void, @ViewBuilder label: () -> Content) -> some View {
        Button(action: action) {
            HStack {
                label()
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
    }
}
