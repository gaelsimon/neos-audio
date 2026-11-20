import SwiftUI

struct ClearQueueConfirmation: ViewModifier {
    @Binding var isPresented: Bool
    let onClear: () -> Void

    func body(content: Content) -> some View {
        content.confirmationDialog("Clear Queue", isPresented: $isPresented) {
            Button("Clear Queue", role: .destructive, action: onClear)
        } message: {
            Text("This removes every track from the queue.")
        }
    }
}
