import SwiftUI

enum DS {
    // MARK: - Colors (dark palette)
    enum Colors {
        static let accent = Color(red: 0.961, green: 0.651, blue: 0.137) // #f5a623
        static let background = Color(white: 0.04)       // Near-black; main content
        static let surface = Color(white: 0.075)          // Sidebar, bottom bar
        static let surfaceElevated = Color(white: 0.12)   // Cards, amp card, hover
        static let surfaceContainer = Color(white: 0.071)  // #121212; service group containers
        static let textSecondary = Color(white: 0.78)
        static let textTertiary = Color(white: 0.55)
        static let border = Color.white.opacity(0.06)
    }

    // MARK: - Corner Radii
    enum Radius {
        static let xs: CGFloat = 2
        static let small: CGFloat = 4
        static let medium: CGFloat = 8
        static let large: CGFloat = 12
        static let xl: CGFloat = 14
    }

    // MARK: - Image Sizes
    enum ImageSize {
        static let listRow: CGFloat = 36
        static let trackListRow: CGFloat = 44
        static let sidebarIcon: CGFloat = 36
        static let containerArt: CGFloat = 240
        static let homeCard: CGFloat = 160
        static let serviceIcon: CGFloat = 40
        static let serviceIconLarge: CGFloat = 48
    }

    // MARK: - Track List
    enum TrackList {
        static let numberWidth: CGFloat = 28
        static let rowHeight: CGFloat = 60
        static let rowSpacing: CGFloat = 0
    }

    // MARK: - Spacing
    enum Spacing {
        static let xxs: CGFloat = 2
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
        static let xxxl: CGFloat = 48
    }

    // MARK: - Sidebar
    enum Sidebar {
        static let itemPaddingH: CGFloat = 10
        static let itemPaddingV: CGFloat = 8
        static let sectionPadding: CGFloat = 16
        static let cornerRadius: CGFloat = Radius.medium
        static let selectedBackground = Color(white: 0.165)
        static let defaultBackground = Color.clear
        static let expandedWidth: CGFloat = 200
    }

    // MARK: - Animation
    enum Animation {
        static let standard: Double = 0.25
        static let quick: Double = 0.15
        static let viewTransition: Double = 0.2
    }

    // MARK: - Icons
    enum Icons {
        // Actions
        static let close = "xmark"
        static let dismiss = "xmark.circle"
        static let add = "plus.circle"
        static let checkmark = "checkmark"
        static let refresh = "arrow.clockwise"
        static let navigate = "arrow.right.circle"
        static let back = "chevron.left"
        static let forward = "chevron.right"
        static let expandUp = "chevron.up"
        static let expandDown = "chevron.down"
        static let settings = "gearshape"
        static let search = "magnifyingglass"
        static let shuffle = "shuffle"

        // Status
        static let warning = "exclamationmark.triangle.fill"
        static let success = "checkmark.circle.fill"
        static let noPlayer = "speaker.slash"
        static let playing = "play.fill"
        static let speakerActive = "speaker.wave.2.fill"

        // Navigation / Sidebar
        static let home = "house.fill"
        static let queue = "list.bullet"
        static let favorites = "heart.fill"
        static let playlists = "music.note.list"
        static let history = "clock.fill"
        static let historyUnfilled = "clock"

        // Media
        static let musicNote = "music.note"
        static let musicNoteTV = "music.note.tv"
        static let musicNoteHouse = "music.note.house"
        static let radio = "radio"
        static let star = "star.fill"

        // Devices / Hardware
        static let power = "power"
        static let speaker = "hifispeaker"
        static let speakerFill = "hifispeaker.fill"
        static let speakerGrouped = "hifispeaker.2"
        static let speakerGroup = "hifispeaker.2.fill"
        static let server = "externaldrive.connected.to.line.below"
        static let cableConnector = "cable.connector"
        static let opticalDisc = "opticaldisc"
        static let recordingTape = "recordingtape"
        static let bluetooth = "dot.radiowaves.left.and.right"
        static let tv = "tv"
        static let fibreChannel = "fibrechannel"
        static let usb = "externaldrive.fill"

        // People / Accounts
        static let person = "person"
        static let personCircle = "person.circle"
        static let personCircleFill = "person.circle.fill"
        static let signIn = "person.crop.circle.badge.plus"

        // Browse
        static let folder = "folder"
        static let album = "square.stack"
        static let genre = "guitars"

        // Support
        static let heart = "heart"
        static let heartFill = "heart.fill"

        // Toasts / Feedback
        static let addedToQueue = "text.badge.plus"
        static let clipboard = "doc.on.clipboard"
        static let personNotFound = "person.slash"
    }

    // MARK: - Typography
    enum Font {
        case pageTitle           // 28pt bold, primary
        case sectionHeader       // 18pt semibold, primary
        case bodyPrimary         // 14pt regular, primary
        case bodyMedium          // 14pt medium, primary
        case bodyEmphasis        // 14pt semibold, primary
        case secondary           // 13pt regular, textSecondary
        case secondaryEmphasis   // 13pt semibold, textSecondary
        case badge               // 13pt semibold, textTertiary
        case sidebarSection      // 12pt medium, textTertiary
        case footnote            // 11pt regular, textTertiary
    }

    // MARK: - Icon Fonts (SF Symbol sizing)
    /// Use these for sizing SF Symbol images. NOT for text.
    /// Convention: plain = default weight, `Emphasis` suffix = semibold.
    /// Sizes with inherent weight (xs, xxl) are intentional; they need
    /// that weight to read well at their size.
    enum IconFont {
        static let xs: SwiftUI.Font = .system(size: 9, weight: .semibold)
        static let sm: SwiftUI.Font = .system(size: 10)
        static let smEmphasis: SwiftUI.Font = .system(size: 10, weight: .semibold)
        static let md: SwiftUI.Font = .system(size: 12)
        static let mdEmphasis: SwiftUI.Font = .system(size: 12, weight: .semibold)
        static let body: SwiftUI.Font = .system(size: 14)
        static let bodyEmphasis: SwiftUI.Font = .system(size: 14, weight: .semibold)
        static let lg: SwiftUI.Font = .system(size: 16)
        static let lgEmphasis: SwiftUI.Font = .system(size: 16, weight: .semibold)
        static let xl: SwiftUI.Font = .system(size: 18)
        static let xxl: SwiftUI.Font = .system(size: 22, weight: .medium)
        static let xxxl: SwiftUI.Font = .system(size: 24)
        static let hero: SwiftUI.Font = .system(size: 32)
        static let jumbo: SwiftUI.Font = .system(size: 40)
        static let mega: SwiftUI.Font = .system(size: 64)

        /// Dynamic icon sizing relative to a container
        static func scaled(_ size: CGFloat) -> SwiftUI.Font {
            .system(size: size)
        }
    }
}

// MARK: - Typography Modifier

struct TypographyModifier: ViewModifier {
    let style: DS.Font

    func body(content: Content) -> some View {
        switch style {
        case .pageTitle:
            content.font(.system(size: 28, weight: .bold)).foregroundStyle(.primary)
        case .sectionHeader:
            content.font(.system(size: 18, weight: .semibold)).foregroundStyle(.primary)
        case .bodyPrimary:
            content.font(.system(size: 14)).foregroundStyle(.primary)
        case .bodyMedium:
            content.font(.system(size: 14, weight: .medium)).foregroundStyle(.primary)
        case .bodyEmphasis:
            content.font(.system(size: 14, weight: .semibold)).foregroundStyle(.primary)
        case .secondary:
            content.font(.system(size: 13)).foregroundStyle(DS.Colors.textSecondary)
        case .secondaryEmphasis:
            content.font(.system(size: 13, weight: .semibold)).foregroundStyle(DS.Colors.textSecondary)
        case .badge:
            content.font(.system(size: 13, weight: .semibold)).foregroundStyle(DS.Colors.textTertiary)
        case .sidebarSection:
            content.font(.system(size: 12, weight: .medium)).foregroundStyle(DS.Colors.textTertiary)
        case .footnote:
            content.font(.system(size: 11)).foregroundStyle(DS.Colors.textTertiary)
        }
    }
}

extension View {
    func typography(_ style: DS.Font) -> some View {
        modifier(TypographyModifier(style: style))
    }
}
