import SwiftUI
import AppKit

/// Accent-tinted spinner that works on macOS (native ProgressView ignores .tint).
struct Spinner: View {
    var size: CGFloat = 20
    var lineWidth: CGFloat = 2.5
    var color: Color = DS.Colors.accent

    var body: some View {
        SpinnerArc(lineWidth: lineWidth, color: NSColor(color))
            .frame(width: size, height: size)
    }
}

// A SwiftUI repeatForever rotation re-renders the window every frame; Core Animation turns it out of process.
private struct SpinnerArc: NSViewRepresentable {
    let lineWidth: CGFloat
    let color: NSColor

    func makeNSView(context: Context) -> SpinnerNSView {
        SpinnerNSView()
    }

    func updateNSView(_ view: SpinnerNSView, context: Context) {
        view.lineWidth = lineWidth
        view.color = color
    }
}

final class SpinnerNSView: NSView {
    static let rotationKey = "rotation"

    let arc = CAShapeLayer()

    var lineWidth: CGFloat = 2.5 {
        didSet { needsLayout = true }
    }

    var color: NSColor = .controlAccentColor {
        didSet { withoutImplicitAnimation { arc.strokeColor = color.cgColor } }
    }

    override var isFlipped: Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        arc.fillColor = nil
        arc.lineCap = .round
        arc.strokeStart = 0.15
        arc.strokeColor = color.cgColor
        layer?.addSublayer(arc)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func layout() {
        super.layout()
        withoutImplicitAnimation {
            arc.frame = bounds
            arc.lineWidth = lineWidth
            let inset = lineWidth / 2
            arc.path = CGPath(ellipseIn: bounds.insetBy(dx: inset, dy: inset), transform: nil)
        }
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard window != nil, arc.animation(forKey: Self.rotationKey) == nil else { return }
        let rotation = CABasicAnimation(keyPath: "transform.rotation.z")
        rotation.fromValue = 0
        rotation.toValue = 2 * CGFloat.pi
        rotation.duration = 0.8
        rotation.repeatCount = .infinity
        arc.add(rotation, forKey: Self.rotationKey)
    }

    private func withoutImplicitAnimation(_ changes: () -> Void) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        changes()
        CATransaction.commit()
    }
}
