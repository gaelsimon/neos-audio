import Foundation

// MARK: - NavigationDestination

/// Single source of truth for "where am I" in the app's navigation.
/// Replaces the scattered SidebarSelection enum with a typed, domain-level contract.
public enum NavigationDestination: Hashable, Sendable {
    case home
    case browse(BrowseTarget)
    case queue
    case settings
    case ampSettings

    /// Stable ID for MainWindowView .id() -- changes only on top-level case change.
    /// For .browse, uses only the root SID so browse depth changes do NOT
    /// trigger view destruction.
    public var stableID: String {
        switch self {
        case .home: return "home"
        case .browse(let target): return "browse-\(target.sid)"
        case .queue: return "queue"
        case .settings: return "settings"
        case .ampSettings: return "ampSettings"
        }
    }
}

// MARK: - BrowseTarget

/// Typed browse location that replaces the untyped BrowseCrumb struct.
/// Carries all context needed to navigate to and display a browse container.
public struct BrowseTarget: Hashable, Sendable {
    public let sid: Int
    public let cid: String?
    public let name: String
    public let imageURL: String
    public let mediaType: MediaType
    public let serviceName: String

    public init(
        sid: Int,
        cid: String? = nil,
        name: String,
        imageURL: String = "",
        mediaType: MediaType = .container,
        serviceName: String = ""
    ) {
        self.sid = sid
        self.cid = cid
        self.name = name
        self.imageURL = imageURL
        self.mediaType = mediaType
        self.serviceName = serviceName
    }

    /// Stable path segment for BrowseContentView .id() continuity.
    /// MUST match the current BrowseCrumb format: "\(sid)\(cid ?? "")"
    public var stableID: String {
        "\(sid)\(cid ?? "")"
    }
}
