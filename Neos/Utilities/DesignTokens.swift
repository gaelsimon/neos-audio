import SwiftUI

enum DS {
    // MARK: - Colors (dark palette)
    enum Colors {
        static let accent = Color(red: 0.961, green: 0.651, blue: 0.137) // #f5a623
        static let background = Color(white: 0.04)       // Near-black; main content
        static let surface = Color(white: 0.075)          // Sidebar, bottom bar
        static let surfaceElevated = Color(white: 0.12)   // Cards, amp card, hover
        static let glassFill = Color(white: 40 / 255).opacity(0.75) // Top bar pills, Tidal's value
        static let glassShade = Color.black.opacity(0.6)            // Bar and sub-header backdrop
        static let glassEdge = Color.white.opacity(0.16)            // Hairline round the top bar pills
        static let surfaceContainer = Color(white: 0.071)  // #121212; service group containers
        static let textSecondary = Color(white: 0.78)
        static let textTertiary = Color(white: 0.55)
        static let destructive = Color(red: 0.902, green: 0.298, blue: 0.259) // #e64c42
        static let border = Color.white.opacity(0.06)
    }

    // MARK: - Corner Radii
    enum Radius {
        static let xs: CGFloat = 2
        static let small: CGFloat = 4
        static let medium: CGFloat = 8
        static let large: CGFloat = 12
        static let xl: CGFloat = 14
        static let artwork: CGFloat = 6        // Cover tiles, cards and the player thumbnail
        static let artworkLarge: CGFloat = 8   // Page-header and now-playing covers
    }

    // MARK: - Image Sizes
    enum ImageSize {
        static let listRow: CGFloat = 44
        static let trackListRow: CGFloat = 44
        static let sidebarIcon: CGFloat = 36
        static let containerArt: CGFloat = 240
        static let homeCard: CGFloat = 160
        static let serviceIcon: CGFloat = 40
        static let serviceIconLarge: CGFloat = 48
    }

    // MARK: - Layout
    enum Layout {
        #if os(macOS)
        static let pageMargin: CGFloat = Spacing.xxl
        static let pageTop: CGFloat = Spacing.xxl
        static let listOutdent: CGFloat = 0
        /// The top bar floats over the page, which leaves this much room under it.
        static let topOverlay: CGFloat = TopBar.height
        #else
        /// The navigation bar's margin on iPhone; the shell sets the iPad's through the environment.
        static let pageMargin: CGFloat = Spacing.lg
        static let regularPageMargin: CGFloat = 20
        static let pageTop: CGFloat = Spacing.sm
        /// Rows pad their own content by this much, so their text meets the title's edge.
        static let listOutdent: CGFloat = Spacing.lg
        /// The navigation bar keeps to the safe area instead of floating over the page.
        static let topOverlay: CGFloat = 0
        #endif
        static let surfaceInset: CGFloat = Spacing.lg
    }

    // MARK: - Top Bar
    enum TopBar {
        static let height: CGFloat = 56
        static let searchWidth: CGFloat = 280
        static let searchMinWidth: CGFloat = 120
        static let controlHeight: CGFloat = 36
        static let arrowFont: SwiftUI.Font = .system(size: 15, weight: .semibold)
    }

    // MARK: - Track List
    enum TrackList {
        static let numberWidth: CGFloat = 28
        static let rowHeight: CGFloat = 60
        static let actionWidth: CGFloat = 36
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
        /// The sidebar list's own row inset, so the logo lines up with the row icons.
        static let logoInset: CGFloat = 16
        static let expandedWidth: CGFloat = 200
    }

    // MARK: - Hit Targets

    /// Apple's touch minimum on iPhone and iPad; the Mac keeps its denser controls.
    enum HitTarget {
        #if os(iOS)
        static let button: CGFloat = 44
        static let slider: CGFloat = 44
        #else
        static let button: CGFloat = 36
        static let slider: CGFloat = 14
        #endif
    }

    /// Touch has no hover, so what hover reveals on the Mac stays visible there.
    static let revealsControlsOnHover: Bool = {
        #if os(iOS)
        false
        #else
        true
        #endif
    }()

    /// A touch screen removes a row by swiping it; the Mac shows a remove button on the row instead.
    static let removesRowsBySwiping: Bool = {
        #if os(iOS)
        true
        #else
        false
        #endif
    }()

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
        static let rename = "pencil"
        static let update = "arrow.down.circle"
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
        case cardTitle           // 13pt semibold, textSecondary; under a card's artwork
        case cardSubtitle        // 13pt regular, textSecondary
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

extension DS.Font {
    /// Fixed sizes on the Mac. On iPhone and iPad, the matching text style, so text follows the reader's size setting.
    var font: SwiftUI.Font {
        #if os(macOS)
        switch self {
        case .pageTitle: .system(size: 28, weight: .bold)
        case .sectionHeader: .system(size: 18, weight: .semibold)
        case .bodyPrimary: .system(size: 14)
        case .bodyMedium: .system(size: 14, weight: .medium)
        case .bodyEmphasis: .system(size: 14, weight: .semibold)
        case .secondary, .cardSubtitle: .system(size: 13)
        case .secondaryEmphasis, .badge, .cardTitle: .system(size: 13, weight: .semibold)
        case .sidebarSection: .system(size: 12, weight: .medium)
        case .footnote: .system(size: 11)
        }
        #else
        switch self {
        case .pageTitle: .system(.title, weight: .bold)
        case .sectionHeader: .system(.title2, weight: .bold)
        case .bodyPrimary: .system(.body)
        case .bodyMedium: .system(.body, weight: .medium)
        case .bodyEmphasis: .system(.body, weight: .semibold)
        case .secondary: .system(.subheadline)
        case .secondaryEmphasis: .system(.subheadline, weight: .semibold)
        case .badge, .cardTitle: .system(.footnote, weight: .semibold)
        case .cardSubtitle: .system(.footnote)
        case .sidebarSection: .system(.footnote, weight: .medium)
        case .footnote: .system(.caption2)
        }
        #endif
    }
}

struct TypographyModifier: ViewModifier {
    let style: DS.Font

    func body(content: Content) -> some View {
        switch style {
        case .pageTitle, .sectionHeader, .bodyPrimary, .bodyMedium, .bodyEmphasis:
            content.font(style.font).foregroundStyle(.primary)
        case .secondary, .secondaryEmphasis, .cardTitle, .cardSubtitle:
            content.font(style.font).foregroundStyle(DS.Colors.textSecondary)
        case .badge, .sidebarSection, .footnote:
            content.font(style.font).foregroundStyle(DS.Colors.textTertiary)
        }
    }
}

extension View {
    func typography(_ style: DS.Font) -> some View {
        modifier(TypographyModifier(style: style))
    }
}
