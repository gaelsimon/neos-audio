import SwiftUI
import NeosDomain

struct ServiceConfigView: View {
    let sources: [MusicSource]
    let hiddenSIDs: Set<Int>
    let onToggle: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text("Show Services")
                .typography(.sectionHeader)
                .padding(.bottom, DS.Spacing.xs)

            ForEach(sources) { source in
                HStack(spacing: DS.Spacing.md) {
                    ServiceBranding.serviceIcon(for: source, size: 32)

                    Text(source.name)
                        .typography(.bodyPrimary)

                    Spacer()

                    Toggle("", isOn: Binding(
                        get: { !hiddenSIDs.contains(source.sid) },
                        set: { _ in onToggle(source.sid) }
                    ))
                    .toggleStyle(.switch)
                    .controlSize(.small)
                }
                .padding(.vertical, DS.Spacing.xs)
            }
        }
        .padding(DS.Spacing.lg)
        .frame(minWidth: 220)
    }
}
