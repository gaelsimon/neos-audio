import AppKit
import SwiftUI

/// macOS paints a list's selection in the solid accent colour only, so the sidebar turns it off and its rows draw their own.
struct SystemSelectionHighlightOff: NSViewRepresentable {
    /// Passed so each selection change reapplies it, should the list have restored its style.
    let selection: AnyHashable?

    func makeNSView(context _: Context) -> Probe { Probe() }

    func updateNSView(_ probe: Probe, context _: Context) { probe.apply() }

    final class Probe: NSView {
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            apply()
        }

        func apply() {
            DispatchQueue.main.async { [weak self] in
                self?.listTable()?.selectionHighlightStyle = .none
            }
        }

        /// The table under this view; others in the window, such as a page's, are left alone.
        private func listTable() -> NSTableView? {
            guard let window else { return nil }
            let center = convert(CGPoint(x: bounds.midX, y: bounds.midY), to: nil)
            var ancestor = superview
            while let view = ancestor {
                let tables = view.descendants(of: NSTableView.self)
                if let table = tables.first(where: { $0.frameInWindow.contains(center) }) { return table }
                if view === window.contentView { return nil }
                ancestor = view.superview
            }
            return nil
        }
    }
}

private extension NSView {
    var frameInWindow: CGRect {
        let shown = enclosingScrollView ?? self
        return shown.convert(shown.bounds, to: nil)
    }

    func descendants<T: NSView>(of type: T.Type) -> [T] {
        subviews.flatMap { child -> [T] in
            (child as? T).map { [$0] + child.descendants(of: type) } ?? child.descendants(of: type)
        }
    }
}
