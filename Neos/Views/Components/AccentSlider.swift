import SwiftUI

extension EnvironmentValues {
    /// The filled part of the volume and progress sliders; white over the iPhone and iPad player's artwork colour.
    @Entry var sliderFill: Color = DS.Colors.accent
}

/// The thin slider of the player's volume. VoiceOver sees a standard `Slider`.
struct AccentSlider: View {
    let value: Double
    var bounds: ClosedRange<Double> = 0...100
    let label: String
    var onEditingChanged: ((Bool) -> Void)?
    let onChange: (Double) -> Void

    @Environment(\.sliderFill) private var fill
    @State private var isHovering = false
    @State private var isDragging = false
    /// The value a touch started from.
    @State private var dragStart: Double?

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

                if isHovering || isDragging {
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
                            dragStart = value
                            onEditingChanged?(true)
                        }
                        report(drag, width: width)
                    }
                    .onEnded { drag in
                        report(drag, width: width)
                        isDragging = false
                        dragStart = nil
                        onEditingChanged?(false)
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

    /// On touch the value follows the finger from where it was, so landing near the end cannot send the speaker there.
    private func report(_ drag: DragGesture.Value, width: CGFloat) {
        let track = SliderDrag(bounds: bounds, width: width)
        #if os(iOS)
        guard drag.translation.width != 0 else { return }
        onChange(track.level(from: dragStart ?? value, movedBy: drag.translation.width))
        #else
        onChange(track.level(at: drag.location.x))
        #endif
    }
}
