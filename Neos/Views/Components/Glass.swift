import SwiftUI
import AppKit

/// AppKit backdrop, so the blur radius can be chosen: the SwiftUI materials expose no such knob.
struct BackdropBlur: NSViewRepresentable {
    let material: NSVisualEffectView.Material

    func makeNSView(context _: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = .withinWindow
        view.state = .active
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context _: Context) {
        view.material = material
    }
}

struct DarkGlass: View {
    var body: some View {
        ZStack {
            BackdropBlur(material: .hudWindow)
            DS.Colors.glassShade
        }
    }
}

struct GlassCapsule: View {
    var tint: Color = .clear

    var body: some View {
        ZStack {
            BackdropBlur(material: .hudWindow)
            DS.Colors.glassFill
            tint
        }
        .clipShape(Capsule())
    }
}

extension View {
    /// A sub-header pinned under the top bar: one glass reaches up behind the bar, so the two never show a seam.
    func stickyHeaderGlass() -> some View {
        padding(.top, DS.TopBar.height)
            .background(DarkGlass())
            .overlay(alignment: .bottom) { Rectangle().fill(DS.Colors.border).frame(height: 1) }
            .padding(.top, -DS.TopBar.height)
    }
}
