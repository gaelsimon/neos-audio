import AppKit
import Foundation
import NeosDomain

/// Status item appearance: the vinyl from the NEOS wordmark, weighted by what the app is doing.
enum MenuBarVinyl: Equatable {
    /// Nothing to control: the bare outer ring.
    case offline
    /// A session, nothing playing: concentric rings, the record at rest.
    case idle
    /// Playing: the record inked in solid.
    case playing
}

func menuBarVinyl(connectionState: ConnectionState, isPlaying: Bool) -> MenuBarVinyl {
    guard connectionState == .connected else { return .offline }
    return isPlaying ? .playing : .idle
}

extension MenuBarVinyl {
    /// A template image, so the menu bar owns the colour in light, dark and while highlighted.
    func image(size: CGFloat = 16) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
            Self.draw(self, in: rect)
            return true
        }
        image.isTemplate = true
        return image
    }

    private static func draw(_ vinyl: MenuBarVinyl, in rect: NSRect) {
        let centre = NSPoint(x: rect.midX, y: rect.midY)
        let outer = min(rect.width, rect.height) / 2 - 0.75
        let label = outer * 0.38
        let hole = outer * 0.12
        let stroke = max(1, outer * 0.2)
        NSColor.black.setFill()
        NSColor.black.setStroke()

        switch vinyl {
        case .offline:
            let ring = NSBezierPath(circleAt: centre, radius: outer - stroke / 2)
            ring.lineWidth = stroke
            ring.stroke()
        case .idle:
            // Rim and spindle only: concentric rings turn to mush at 16 pt.
            let ring = NSBezierPath(circleAt: centre, radius: outer - stroke / 2)
            ring.lineWidth = stroke
            ring.stroke()
            NSBezierPath(circleAt: centre, radius: label * 0.75).fill()
        case .playing:
            // Even-odd over three concentric circles inks the disc, clears the label, re-inks the hole.
            let disc = NSBezierPath()
            disc.windingRule = .evenOdd
            disc.append(NSBezierPath(circleAt: centre, radius: outer))
            disc.append(NSBezierPath(circleAt: centre, radius: label))
            disc.append(NSBezierPath(circleAt: centre, radius: hole))
            disc.fill()
        }
    }
}

private extension NSBezierPath {
    convenience init(circleAt centre: NSPoint, radius: CGFloat) {
        self.init(ovalIn: NSRect(
            x: centre.x - radius, y: centre.y - radius,
            width: radius * 2, height: radius * 2
        ))
    }
}
