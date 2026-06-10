import SwiftUI

/// A horizontal scroll view that shows gradient edge shadows when content
/// overflows, and navigation arrows on hover for page-by-page scrolling.
struct FadingHorizontalScroll<Content: View>: View {
    var gradientColor: Color = DS.Colors.background
    @ViewBuilder let content: () -> Content

    @State private var canScrollLeft = false
    @State private var canScrollRight = false
    @State private var isHovering = false
    @State private var nsScrollView: NSScrollView?

    private let gradientWidth: CGFloat = 48
    private let arrowButtonSize: CGFloat = 32

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            content()
                .background(
                    ScrollEdgeObserver(
                        canScrollLeft: $canScrollLeft,
                        canScrollRight: $canScrollRight
                    ) { nsScrollView = $0 }
                )
        }
        .overlay(alignment: .leading) {
            if canScrollLeft {
                edgeOverlay(leading: true)
            }
        }
        .overlay(alignment: .trailing) {
            if canScrollRight {
                edgeOverlay(leading: false)
            }
        }
        .onHover { isHovering = $0 }
        .compositingGroup()
        .animation(.easeInOut(duration: DS.Animation.quick), value: canScrollLeft)
        .animation(.easeInOut(duration: DS.Animation.quick), value: canScrollRight)
    }

    // MARK: - Edge Overlay

    @ViewBuilder
    private func edgeOverlay(leading: Bool) -> some View {
        ZStack(alignment: leading ? .leading : .trailing) {
            gradientColor
                .frame(width: gradientWidth)
                .mask(
                    LinearGradient(
                        colors: [.black, .black.opacity(0)],
                        startPoint: leading ? .leading : .trailing,
                        endPoint: leading ? .trailing : .leading
                    )
                )
                .allowsHitTesting(false)
                .accessibilityHidden(true)

            if isHovering {
                Button {
                    scrollByPage(direction: leading ? -1 : 1)
                } label: {
                    Image(systemName: leading ? DS.Icons.back : DS.Icons.forward)
                        .font(DS.IconFont.body)
                        .foregroundStyle(.primary)
                        .frame(width: arrowButtonSize, height: arrowButtonSize)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .buttonStyle(.plain)
                .padding(.horizontal, DS.Spacing.sm)
                .transition(.opacity)
            }
        }
        .frame(maxHeight: .infinity)
    }

    // MARK: - Programmatic Scroll

    private func scrollByPage(direction: CGFloat) {
        guard let scrollView = nsScrollView,
              scrollView.window != nil else { return }
        let clip = scrollView.contentView
        let pageWidth = clip.bounds.width * 0.8
        let currentX = clip.bounds.origin.x
        let newX = currentX + direction * pageWidth
        let maxX = max(0, (scrollView.documentView?.frame.width ?? 0) - clip.bounds.width)
        let clampedX = min(max(0, newX), maxX)

        NSAnimationContext.runAnimationGroup { context in
            context.duration = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? 0 : 0.3
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            clip.animator().setBoundsOrigin(NSPoint(x: clampedX, y: clip.bounds.origin.y))
        }
    }
}

// MARK: - NSScrollView Observer

/// Invisible helper that finds the enclosing NSScrollView and observes
/// its clip-view bounds to report whether the user can scroll left/right.
private struct ScrollEdgeObserver: NSViewRepresentable {
    @Binding var canScrollLeft: Bool
    @Binding var canScrollRight: Bool
    var onScrollViewFound: ((NSScrollView) -> Void)?

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            guard view.window != nil else { return }
            context.coordinator.setup(from: view)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(
            canScrollLeft: $canScrollLeft,
            canScrollRight: $canScrollRight,
            onFound: onScrollViewFound
        )
    }

    final class Coordinator {
        private let canScrollLeft: Binding<Bool>
        private let canScrollRight: Binding<Bool>
        private let onFound: ((NSScrollView) -> Void)?
        private var observers: [NSObjectProtocol] = []
        private var isSetup = false

        init(
            canScrollLeft: Binding<Bool>,
            canScrollRight: Binding<Bool>,
            onFound: ((NSScrollView) -> Void)?
        ) {
            self.canScrollLeft = canScrollLeft
            self.canScrollRight = canScrollRight
            self.onFound = onFound
        }

        func setup(from view: NSView) {
            guard !isSetup else { return }
            guard let scrollView = view.enclosingScrollView else { return }
            isSetup = true
            onFound?(scrollView)

            let clip = scrollView.contentView
            clip.postsBoundsChangedNotifications = true
            clip.postsFrameChangedNotifications = true

            // Scroll position changes
            observers.append(
                NotificationCenter.default.addObserver(
                    forName: NSView.boundsDidChangeNotification,
                    object: clip, queue: .main
                ) { [weak self] _ in self?.update(scrollView) }
            )
            // Visible area resize
            observers.append(
                NotificationCenter.default.addObserver(
                    forName: NSView.frameDidChangeNotification,
                    object: clip, queue: .main
                ) { [weak self] _ in self?.update(scrollView) }
            )
            // Content size changes (items added/removed)
            if let docView = scrollView.documentView {
                docView.postsFrameChangedNotifications = true
                observers.append(
                    NotificationCenter.default.addObserver(
                        forName: NSView.frameDidChangeNotification,
                        object: docView, queue: .main
                    ) { [weak self] _ in self?.update(scrollView) }
                )
            }

            update(scrollView)
        }

        private func update(_ scrollView: NSScrollView) {
            guard scrollView.window != nil else { return }
            let clip = scrollView.contentView
            let docWidth = scrollView.documentView?.frame.width ?? 0
            let visibleWidth = clip.bounds.width
            let offset = clip.bounds.origin.x

            let newLeft = offset > 1
            let newRight = offset + visibleWidth < docWidth - 1

            // Dispatch to avoid "Modifying state during view update"
            if canScrollLeft.wrappedValue != newLeft || canScrollRight.wrappedValue != newRight {
                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    if self.canScrollLeft.wrappedValue != newLeft {
                        self.canScrollLeft.wrappedValue = newLeft
                    }
                    if self.canScrollRight.wrappedValue != newRight {
                        self.canScrollRight.wrappedValue = newRight
                    }
                }
            }
        }

        private func teardown() {
            observers.forEach { NotificationCenter.default.removeObserver($0) }
            observers.removeAll()
        }

        deinit {
            teardown()
        }
    }
}
