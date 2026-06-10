import AppKit
import SwiftUI
import NeosDomain

// MARK: - Volume Panel State

/// Bridges state between VolumeControlView (SwiftUI) and the floating NSPanel.
@MainActor @Observable
final class VolumePanelState {
    var volume: Double = 0
    var effectiveMax: Double = 100
    var isDragging = false
    var setVolume: ((Int) -> Void)?
    var setAdjustingVolume: ((Bool) -> Void)?
    /// Populated by VolumeHoverNSView; returns true if the cursor is over the panel or button.
    var checkMouseInside: (() -> Bool)?
}

// MARK: - Volume Panel Content

/// SwiftUI view hosted inside the floating NSPanel.
struct VolumePanelContent: View {
    let panelState: VolumePanelState

    private static let trackHeight: CGFloat = 120
    private static let trackWidth: CGFloat = 4
    private static let thumbSize: CGFloat = 14

    var body: some View {
        VStack(spacing: 6) {
            Text("\(Int(panelState.volume))")
                .typography(.badge)
                .foregroundStyle(.white)
                .monospacedDigit()

            GeometryReader { geo in
                let height = geo.size.height
                let fraction = panelState.volume / max(panelState.effectiveMax, 1)
                ZStack(alignment: .bottom) {
                    Capsule().fill(Color.white.opacity(0.2)).frame(width: Self.trackWidth)
                    Capsule().fill(DS.Colors.accent)
                        .frame(width: Self.trackWidth, height: max(0, fraction * height))
                    Circle().fill(DS.Colors.accent)
                        .frame(width: Self.thumbSize, height: Self.thumbSize)
                        .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
                        .offset(y: -(fraction * height) + Self.thumbSize / 2)
                }
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            if !panelState.isDragging {
                                panelState.isDragging = true
                                panelState.setAdjustingVolume?(true)
                            }
                            let clamped = max(0, min(1, 1 - value.location.y / height))
                            panelState.volume = clamped * panelState.effectiveMax
                            panelState.setVolume?(Int(panelState.volume))
                        }
                        .onEnded { value in
                            let clamped = max(0, min(1, 1 - value.location.y / height))
                            panelState.volume = clamped * panelState.effectiveMax
                            panelState.setVolume?(Int(panelState.volume))
                            panelState.isDragging = false
                            panelState.setAdjustingVolume?(false)
                        }
                )
            }
            .frame(width: 30, height: Self.trackHeight)
            .accessibilityLabel("Volume")
            .accessibilityValue("\(Int(panelState.volume)) percent")
        }
        .padding(.horizontal, DS.Spacing.md)
        .padding(.vertical, DS.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.large)
                .fill(DS.Colors.surfaceElevated)
                .shadow(color: .black.opacity(0.5), radius: 10, y: -2)
        )
    }
}

// MARK: - Hover Zone (AppKit)

/// SwiftUI `.onHover` cannot track outside a view's layout frame, and
/// NSTrackingArea clips to the owning view's visible rect. This view uses
/// NSTrackingArea for the button area (initial hover) and an NSEvent local
/// monitor for the expanded popover area. The popover itself is an NSPanel
/// (separate window) so gestures work outside the toolbar bounds.
struct VolumeHoverZone: NSViewRepresentable {
    let isExpanded: Bool
    let panelState: VolumePanelState
    let onHoverChanged: (Bool) -> Void

    func makeNSView(context: Context) -> VolumeHoverNSView {
        let v = VolumeHoverNSView()
        v.callback = onHoverChanged
        v.panelState = panelState
        v.expanded = isExpanded
        panelState.checkMouseInside = { [weak v] in
            v?.isPointInsideCurrentMouse() ?? false
        }
        return v
    }

    func updateNSView(_ v: VolumeHoverNSView, context: Context) {
        v.callback = onHoverChanged
        v.panelState = panelState
        if v.expanded != isExpanded {
            let wasExpanded = v.expanded
            v.expanded = isExpanded
            v.updateMonitoring()
            if isExpanded {
                v.showPanel()
            } else {
                v.hidePanel()
                // After closing, check if mouse is still over the button so
                // a subsequent hover-in is detected without requiring mouse-exit first.
                if wasExpanded {
                    v.resetHoverState()
                }
            }
        }
    }

    static func dismantleNSView(_ v: VolumeHoverNSView, coordinator: ()) {
        v.tearDown()
    }
}

// MARK: - Volume Hover NSView

final class VolumeHoverNSView: NSView {
    var expanded = false
    var callback: ((Bool) -> Void)?
    var panelState: VolumePanelState?
    private var isMouseInside = false
    private var monitor: Any?
    private var panel: NSPanel?

    override var isFlipped: Bool { true }

    /// Rect covering button + gap + popover, in the view's local (flipped) coords.
    private var expandedRect: NSRect {
        NSRect(x: bounds.midX - 35, y: -210, width: 70, height: 210 + bounds.height)
    }

    // MARK: - Panel Management

    func showPanel() {
        guard let ps = panelState, let parentWindow = window else { return }

        if panel == nil {
            let p = NSPanel(
                contentRect: .zero,
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: true
            )
            p.isFloatingPanel = true
            p.level = .floating
            p.backgroundColor = .clear
            p.isOpaque = false
            p.hasShadow = false
            p.animationBehavior = .none
            p.acceptsMouseMovedEvents = true
            p.ignoresMouseEvents = false

            let hosting = NSHostingView(rootView: VolumePanelContent(panelState: ps))
            p.contentView = hosting
            p.setContentSize(hosting.fittingSize)
            panel = p
        }

        guard let p = panel else { return }

        // Position above the mute button
        let btnRect = convert(bounds, to: nil)
        let screenRect = parentWindow.convertToScreen(btnRect)
        let panelSize = p.frame.size
        p.setFrameOrigin(NSPoint(
            x: screenRect.midX - panelSize.width / 2,
            y: screenRect.maxY + 4
        ))

        p.alphaValue = 0
        parentWindow.addChildWindow(p, ordered: .above)
        p.orderFront(nil)
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.15
            p.animator().alphaValue = 1
        }
    }

    func hidePanel() {
        guard let p = panel else { return }
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.15
            p.animator().alphaValue = 0
        } completionHandler: {
            p.parent?.removeChildWindow(p)
            p.orderOut(nil)
        }
    }

    func tearDown() {
        if let m = monitor { NSEvent.removeMonitor(m); monitor = nil }
        for a in trackingAreas { removeTrackingArea(a) }
        if let p = panel {
            p.parent?.removeChildWindow(p)
            p.orderOut(nil)
            panel = nil
        }
    }

    // MARK: - Hover Monitoring

    func updateMonitoring() {
        for a in trackingAreas { removeTrackingArea(a) }
        addTrackingArea(NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeInActiveApp],
            owner: self
        ))

        if let m = monitor { NSEvent.removeMonitor(m); monitor = nil }
        if expanded {
            monitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged, .leftMouseDown, .leftMouseUp]) { [weak self] event in
                self?.handleMouseEvent(event)
                return event
            }
            DispatchQueue.main.async { [weak self] in self?.checkCurrentPosition() }
        }
    }

    private func screenMousePoint(from event: NSEvent) -> NSPoint {
        guard let eventWindow = event.window else { return event.locationInWindow }
        return eventWindow.convertToScreen(
            NSRect(origin: event.locationInWindow, size: .zero)
        ).origin
    }

    private func checkCurrentPosition() {
        guard expanded else { return }
        let screenPt = NSEvent.mouseLocation
        let inside = isPointInsideAnyRegion(screenPt)
        if inside != isMouseInside {
            isMouseInside = inside
            callback?(inside)
        }
    }

    /// Public entry point for SwiftUI to query if the cursor is currently over the panel or button.
    func isPointInsideCurrentMouse() -> Bool {
        isPointInsideAnyRegion(NSEvent.mouseLocation)
    }

    private func isPointInsideAnyRegion(_ screenPt: NSPoint) -> Bool {
        // Check the panel window frame (the slider popover itself)
        if let panelFrame = panel?.frame, panelFrame.contains(screenPt) {
            return true
        }
        // Check the button area via local coordinate mapping
        guard let myWindow = window else { return false }
        let winPt = myWindow.convertFromScreen(NSRect(origin: screenPt, size: .zero)).origin
        let viewPt = convert(winPt, from: nil)
        return expandedRect.contains(viewPt)
    }

    private func handleMouseEvent(_ event: NSEvent) {
        guard expanded else { return }
        let screenPt = screenMousePoint(from: event)
        let inside = isPointInsideAnyRegion(screenPt)
        if inside != isMouseInside {
            isMouseInside = inside
            callback?(inside)
        }
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        updateMonitoring()
    }

    /// Reset hover state after panel closes, then re-check if the cursor is
    /// still over the button so a new hover-in can be detected without requiring
    /// the user to physically exit and re-enter.
    func resetHoverState() {
        isMouseInside = false
        DispatchQueue.main.async { [weak self] in
            guard let self, !self.expanded else { return }
            let screenPt = NSEvent.mouseLocation
            let localPt = self.convert(
                self.window?.convertFromScreen(NSRect(origin: screenPt, size: .zero)).origin ?? .zero,
                from: nil
            )
            if self.bounds.contains(localPt) {
                self.isMouseInside = true
                self.callback?(true)
            }
        }
    }

    override func mouseEntered(with event: NSEvent) {
        guard !expanded else { return }
        isMouseInside = true
        callback?(true)
    }

    override func mouseExited(with event: NSEvent) {
        guard !expanded else { return }
        isMouseInside = false
        callback?(false)
    }
}
