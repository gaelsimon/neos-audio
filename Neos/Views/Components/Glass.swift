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
