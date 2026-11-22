import CoreGraphics

/// Where a drag along a slider's track takes its value.
struct SliderDrag {
    let bounds: ClosedRange<Double>
    let width: CGFloat

    private var span: Double { bounds.upperBound - bounds.lowerBound }

    /// A click puts the value under the pointer, as a Mac slider does.
    func level(at x: CGFloat) -> Double {
        guard width > 0 else { return bounds.lowerBound }
        return clamped(bounds.lowerBound + Double(x / width) * span)
    }

    /// A touch moves the value by the distance dragged, so landing on the track changes nothing.
    func level(from start: Double, movedBy distance: CGFloat) -> Double {
        guard width > 0 else { return clamped(start) }
        return clamped(start + Double(distance / width) * span)
    }

    private func clamped(_ value: Double) -> Double {
        min(max(value, bounds.lowerBound), bounds.upperBound)
    }
}
