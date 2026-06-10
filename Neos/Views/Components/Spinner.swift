import SwiftUI

/// Accent-tinted spinner that works on macOS (native ProgressView ignores .tint).
struct Spinner: View {
    var size: CGFloat = 20
    var lineWidth: CGFloat = 2.5
    var color: Color = DS.Colors.accent

    @State private var isAnimating = false

    var body: some View {
        Circle()
            .trim(from: 0.15, to: 1)
            .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            .frame(width: size, height: size)
            .rotationEffect(.degrees(isAnimating ? 360 : 0))
            .animation(.linear(duration: 0.8).repeatForever(autoreverses: false), value: isAnimating)
            .onAppear { isAnimating = true }
    }
}
