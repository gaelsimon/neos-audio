import SwiftUI

/// The speaker's level for a moment after each press of the phone's volume buttons, in place of the phone's own indicator.
struct VolumeButtonIndicator: View {
    let state: AppState
    let presses: Int
    @State private var isShown = false

    private static let barWidth: CGFloat = 120

    private var fraction: Double {
        min(Double(state.volume) / Double(max(state.maxVolume ?? 100, 1)), 1)
    }

    var body: some View {
        ZStack {
            if isShown {
                indicator
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: DS.Animation.standard), value: isShown)
        .task(id: presses) {
            guard presses > 0 else { return }
            isShown = true
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled else { return }
            isShown = false
        }
    }

    private var indicator: some View {
        HStack(spacing: DS.Spacing.sm) {
            Image(systemName: DS.Icons.speakerFill)
                .font(DS.IconFont.md)
            Capsule()
                .fill(.white.opacity(0.2))
                .frame(width: Self.barWidth, height: 4)
                .overlay(alignment: .leading) {
                    Capsule()
                        .fill(DS.Colors.accent)
                        .frame(width: Self.barWidth * fraction, height: 4)
                }
            Text("\(state.volume)")
                .typography(.secondary)
                .monospacedDigit()
                .frame(minWidth: 24, alignment: .trailing)
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.Spacing.sm)
        .background(.regularMaterial, in: Capsule())
        .shadow(color: .black.opacity(0.2), radius: 6, y: 2)
        .padding(.top, DS.Spacing.xs)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Volume")
        .accessibilityValue("\(state.volume)")
    }
}
