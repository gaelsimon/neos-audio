import SwiftUI

/// Accent-tinted spinner that works on macOS (native ProgressView ignores .tint).
struct Spinner: View {
    var size: CGFloat = 20
    var lineWidth: CGFloat = 2.5
    var color: Color = DS.Colors.accent

    var body: some View {
        SpinnerArc(lineWidth: lineWidth, color: color)
            .frame(width: size, height: size)
    }
}

// A SwiftUI repeatForever rotation re-renders the window every frame; Core Animation turns it out of process.
private struct SpinnerArc {
    let lineWidth: CGFloat
    let color: Color

    func update(_ view: SpinnerView, in environment: EnvironmentValues) {
        view.lineWidth = lineWidth
        view.color = color.resolve(in: environment).cgColor
    }
}

#if os(macOS)
extension SpinnerArc: NSViewRepresentable {
    func makeNSView(context _: Context) -> SpinnerView {
        SpinnerView()
    }

    func updateNSView(_ view: SpinnerView, context: Context) {
        update(view, in: context.environment)
    }
}
#else
extension SpinnerArc: UIViewRepresentable {
    func makeUIView(context _: Context) -> SpinnerView {
        SpinnerView()
    }

    func updateUIView(_ view: SpinnerView, context: Context) {
        update(view, in: context.environment)
    }
}
#endif

final class SpinnerView: PlatformView {
    static let rotationKey = "rotation"

    let arc = CAShapeLayer()

    var lineWidth: CGFloat = 2.5 {
        didSet { invalidateArc() }
    }

    var color = CGColor(gray: 1, alpha: 1) {
        didSet { withoutImplicitAnimation { arc.strokeColor = color } }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        arc.fillColor = nil
        arc.lineCap = .round
        arc.strokeStart = 0.15
        arc.strokeColor = color
        #if os(macOS)
        wantsLayer = true
        layer?.addSublayer(arc)
        #else
        layer.addSublayer(arc)
        #endif
    }

    required init?(coder: NSCoder) {
        nil
    }

    #if os(macOS)
    override var isFlipped: Bool { true }

    override func layout() {
        super.layout()
        layoutArc()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        startRotating()
    }

    private func invalidateArc() {
        needsLayout = true
    }
    #else
    override func layoutSubviews() {
        super.layoutSubviews()
        layoutArc()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        startRotating()
    }

    private func invalidateArc() {
        setNeedsLayout()
    }
    #endif

    private func layoutArc() {
        withoutImplicitAnimation {
            arc.frame = bounds
            arc.lineWidth = lineWidth
            let inset = lineWidth / 2
            arc.path = CGPath(ellipseIn: bounds.insetBy(dx: inset, dy: inset), transform: nil)
        }
    }

    // Kept on completion: iOS strips finished animations when the app goes to the background.
    private func startRotating() {
        guard window != nil, arc.animation(forKey: Self.rotationKey) == nil else { return }
        let rotation = CABasicAnimation(keyPath: "transform.rotation.z")
        rotation.fromValue = 0
        rotation.toValue = 2 * CGFloat.pi
        rotation.duration = 0.8
        rotation.repeatCount = .infinity
        rotation.isRemovedOnCompletion = false
        arc.add(rotation, forKey: Self.rotationKey)
    }

    private func withoutImplicitAnimation(_ changes: () -> Void) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        changes()
        CATransaction.commit()
    }
}
