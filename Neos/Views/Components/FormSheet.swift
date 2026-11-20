import SwiftUI

/// A form in a sheet, with Cancel and one confirming action: in the bar on iPhone and iPad, under the form on the Mac.
struct FormSheet<Content: View>: View {
    let title: String
    let confirmTitle: String
    var canConfirm = true
    let onCancel: () -> Void
    let onConfirm: () -> Void
    @ViewBuilder let content: Content

    var body: some View {
        #if os(iOS)
        NavigationStack {
            Form { content }
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel", action: onCancel)
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button(confirmTitle, action: onConfirm)
                            .disabled(!canConfirm)
                    }
                }
        }
        .cappedTextSize()
        #else
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .typography(.sectionHeader)
                .padding(.horizontal, DS.Layout.formInset)
                .padding(.top, DS.Layout.formInset)

            Form { content }
                .formStyle(.grouped)
                .scrollContentBackground(.hidden)
                // As tall as its rows: a sheet has no height of its own to give a scrolling form.
                .scrollDisabled(true)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Spacer()
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Button(confirmTitle, action: onConfirm)
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .tint(DS.Colors.accent)
                    .disabled(!canConfirm)
            }
            .padding([.horizontal, .bottom], DS.Layout.formInset)
        }
        .frame(width: 420)
        #endif
    }
}
