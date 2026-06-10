import AppKit
import SwiftUI

/// Circular icon button with size variants, matching Qobuz/Tidal style.
struct CircularIconButton: View {
    enum Size {
        case large   // Primary action (play button)
        case medium  // Secondary actions (add to queue, etc.)
        case small   // Compact header

        var diameter: CGFloat {
            switch self {
            case .large: 56
            case .medium: 40
            case .small: 32
            }
        }

        var iconSize: CGFloat {
            switch self {
            case .large: 20
            case .medium: 16
            case .small: 14
            }
        }
    }

    enum Style {
        case primary    // Solid accent background
        case secondary  // Subtle elevated background

        func backgroundColor(isHovered: Bool) -> Color {
            switch self {
            case .primary:
                return DS.Colors.accent
            case .secondary:
                return isHovered ? DS.Colors.surfaceElevated.opacity(0.8) : DS.Colors.surfaceElevated.opacity(0.6)
            }
        }

        func iconColor(isHovered: Bool) -> Color {
            switch self {
            case .primary:
                return .black
            case .secondary:
                return isHovered ? .white : DS.Colors.textSecondary
            }
        }
    }

    let icon: String
    let size: Size
    let style: Style
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Circle()
                .fill(style.backgroundColor(isHovered: isHovered))
                .frame(width: size.diameter, height: size.diameter)
                .overlay {
                    Image(systemName: icon)
                        .font(DS.IconFont.scaled(size.iconSize).weight(.semibold))
                        .foregroundStyle(style.iconColor(isHovered: isHovered))
                }
        }
        .buttonStyle(.plain)
        .contentShape(Circle())
        .onHover { hovering in
            isHovered = hovering
            if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
        }
        .animation(.easeInOut(duration: DS.Animation.quick), value: isHovered)
    }
}
