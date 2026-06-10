import SwiftUI

struct SignInPromptView: View {
    let title: String
    let message: String
    let style: Style
    let onSignIn: () -> Void

    enum Style {
        /// Card with container background; used inline within scrollable content.
        case card
        /// Centered in available space; used as a full-screen replacement.
        case centered
    }

    var body: some View {
        VStack(spacing: DS.Spacing.lg) {
            if style == .centered { Spacer() }

            Image(systemName: DS.Icons.signIn)
                .font(DS.IconFont.xxxl)
                .foregroundStyle(DS.Colors.textTertiary)

            Text(title)
                .typography(.sectionHeader)

            Text(message)
                .typography(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)

            Button(action: onSignIn) {
                Text("Sign In")
                    .typography(.bodyEmphasis)
            }
            .buttonStyle(.bordered)
            .tint(DS.Colors.accent)
            .controlSize(.large)

            if style == .centered { Spacer() }
        }
        .padding(.vertical, style == .card ? DS.Spacing.xxl : 0)
        .frame(maxWidth: .infinity)
        .modifier(CardBackgroundModifier(enabled: style == .card))
    }
}

private struct CardBackgroundModifier: ViewModifier {
    let enabled: Bool

    func body(content: Content) -> some View {
        if enabled {
            content
                .background(
                    RoundedRectangle(cornerRadius: DS.Radius.large)
                        .fill(DS.Colors.surfaceContainer)
                )
                .padding(.horizontal, DS.Spacing.md)
        } else {
            content.padding()
        }
    }
}
