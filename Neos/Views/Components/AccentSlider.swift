import SwiftUI

extension EnvironmentValues {
    /// The filled part of the volume and progress sliders; white over the iPhone and iPad player's artwork colour.
    @Entry var sliderFill: Color = DS.Colors.accent
}

/// The thin accent slider of the player bar and the amp page. VoiceOver sees a standard `Slider`.
struct AccentSlider: View {
    let value: Double
    var bounds: ClosedRange<Double> = 0...100
    let label: String
    var showsKnob = true
    var onEditingChanged: (Bool) -> Void = { _ in }
    let onChange: (Double) -> Void

    @Environment(\.sliderFill) private var fill
    @State private var isHovering = false
    @State private var isDragging = false

    private static let trackHeight: CGFloat = 4
    private static let knobSize: CGFloat = 14

    private var fraction: Double {
        let span = bounds.upperBound - bounds.lowerBound
        guard span > 0 else { return 0 }
        return min(max((value - bounds.lowerBound) / span, 0), 1)
    }

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.15))
                    .frame(height: Self.trackHeight)

                Capsule()
                    .fill(fill)
                    .frame(width: max(0, fraction * width), height: Self.trackHeight)

                if showsKnob && (isHovering || isDragging) {
                    Circle()
                        .fill(fill)
                        .frame(width: Self.knobSize, height: Self.knobSize)
                        .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
                        .offset(x: fraction * width - Self.knobSize / 2)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .frame(height: geo.size.height)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        if !isDragging {
                            isDragging = true
                            onEditingChanged(true)
                        }
                        onChange(level(at: drag.location.x, width: width))
                    }
                    .onEnded { drag in
                        onChange(level(at: drag.location.x, width: width))
                        isDragging = false
                        onEditingChanged(false)
                    }
            )
            .onHover { hovering in
                withAnimation(.easeInOut(duration: DS.Animation.quick)) {
                    isHovering = hovering
                }
            }
        }
        .frame(height: max(Self.knobSize, DS.HitTarget.slider))
        .accessibilityRepresentation {
            Slider(value: Binding(get: { value }, set: onChange), in: bounds) {
                Text(label)
            }
        }
    }

    private func level(at x: CGFloat, width: CGFloat) -> Double {
        let position = width > 0 ? min(max(x / width, 0), 1) : 0
        return bounds.lowerBound + position * (bounds.upperBound - bounds.lowerBound)
    }
}
