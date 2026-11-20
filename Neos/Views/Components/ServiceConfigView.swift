import SwiftUI
import NeosDomain

struct ServiceConfigView: View {
    let sources: [MusicSource]
    let hiddenSIDs: Set<Int>
    let onToggle: (Int) -> Void

    var body: some View {
        ForEach(sources) { source in
            HStack(spacing: DS.Spacing.md) {
                ServiceBranding.serviceIcon(for: source, size: 32)

                Text(source.name)
                    .typography(.bodyPrimary)

                Spacer()

                Toggle(source.name, isOn: Binding(
                    get: { !hiddenSIDs.contains(source.sid) },
                    set: { _ in onToggle(source.sid) }
                ))
                .labelsHidden()
                .toggleStyle(.switch)
                .tint(DS.Colors.accent)
                .controlSize(.small)
            }
            .padding(.vertical, DS.Spacing.xs)
        }
    }
}
