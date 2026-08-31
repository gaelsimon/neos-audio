import Foundation

/// Type-safe accessibility identifiers organized by screen.
/// Use with `.accessibilityIdentifier(AccessibilityID.Sidebar.home)` in views.
/// Views are NOT wired in Phase 17; wiring happens in Phase 18.
enum AccessibilityID {

    // MARK: - Sidebar

    enum Sidebar {
        static let home = "sidebar.home"
        static let queue = "sidebar.queue"
        static let scrollView = "sidebar.scrollView"
        static let ampCard = "sidebar.ampCard"
        static let powerButton = "sidebar.powerButton"
        static let scanButton = "sidebar.scanButton"
        static let manualIPField = "sidebar.manualIPField"
        static let manualConnectButton = "sidebar.manualConnectButton"
        static let disconnectButton = "sidebar.disconnectButton"
        static let servicesSection = "sidebar.servicesSection"
        static let librarySection = "sidebar.librarySection"

        static func source(_ sid: Int) -> String {
            "sidebar.source.\(sid)"
        }
    }

    // MARK: - Player Controls

    enum Player {
        static let playPause = "player.playPause"
        static let previous = "player.previous"
        static let next = "player.next"
        static let shuffle = "player.shuffle"
        static let repeatMode = "player.repeat"
        static let volumeMute = "player.volumeMute"
        static let volumeSlider = "player.volumeSlider"
        static let progressBar = "player.progressBar"
        static let songTitle = "player.songTitle"
        static let artistName = "player.artistName"
        static let albumArt = "player.albumArt"
        static let qualityBadge = "player.qualityBadge"
    }

    // MARK: - Home

    enum Home {
        static let view = "home.view"
        static let header = "home.header"
        static let configButton = "home.configButton"
        static let refreshButton = "home.refreshButton"
        static let recentlyPlayed = "home.recentlyPlayed"
        static let favorites = "home.favorites"
        static let emptyState = "home.emptyState"
    }

    // MARK: - Browse

    enum Browse {
        static let view = "browse.view"
        static let containerArt = "browse.containerArt"
        static let containerTitle = "browse.containerTitle"
        static let playContainer = "browse.playContainer"
        static let addToQueue = "browse.addToQueue"
    }

    // MARK: - Queue

    enum Queue {
        static let view = "queue.view"
        static let header = "queue.header"
        static let clearButton = "queue.clearButton"
    }

    // MARK: - Search

    enum Search {
        static let clearButton = "search.clearButton"
        static let resultsView = "search.resultsView"
        static let historyOverlay = "search.historyOverlay"
        static let clearHistoryButton = "search.clearHistoryButton"
    }

    // MARK: - Settings

    enum Settings {
        static let view = "settings.view"
        static let profileButton = "settings.profileButton"
        // Account form elements
        static let emailField = "settings.emailField"
        static let passwordField = "settings.passwordField"
        static let signInButton = "settings.signInButton"
        static let signOutButton = "settings.signOutButton"
        static let signedInUser = "settings.signedInUser"
        static let signInError = "settings.signInError"
        // Volume Limit
        static let volumeLimitToggle = "settings.volumeLimitToggle"
        static let volumeLimitSlider = "settings.volumeLimitSlider"
        static let volumeLimitLabel = "settings.volumeLimitLabel"
        // Cache
        static let cacheSizeLabel = "settings.cacheSizeLabel"
        static let clearCacheButton = "settings.clearCacheButton"
        // About
        static let aboutVersion = "settings.aboutVersion"
        static let aboutBuild = "settings.aboutBuild"
        static let aboutCopyright = "settings.aboutCopyright"
        // Support
        static let supportButton = "settings.supportButton"
        // Diagnostics
        static let diagnosticsList = "settings.diagnosticsList"
        static let copyDiagnosticsButton = "settings.copyDiagnosticsButton"
        // Remember Me
        static let rememberMeToggle = "settings.rememberMeToggle"
    }

    // MARK: - Disconnected

    enum Disconnected {
        static let view = "disconnected.view"
        static let title = "disconnected.title"
        static let statusIndicator = "disconnected.statusIndicator"
    }

    // MARK: - Discovery

    enum Discovery {
        static let view = "discovery.view"
        static let deviceGrid = "discovery.deviceGrid"
        static let manualConnectSection = "discovery.manualConnectSection"
        static let manualConnectToggle = "discovery.manualConnectToggle"
        static let progressIndicator = "discovery.progressIndicator"

        static func deviceCard(_ host: String) -> String {
            "discovery.deviceCard.\(host)"
        }
    }

    // MARK: - Top Bar

    enum TopBar {
        static let backButton = "topBar.backButton"
        static let forwardButton = "topBar.forwardButton"
        static let searchField = "topBar.searchField"
        static let profileButton = "topBar.profileButton"
    }

    // MARK: - Queue Panel

    enum QueuePanel {
        static let view = "queuePanel.view"
        static let toggleButton = "queuePanel.toggleButton"
        static let tabBar = "queuePanel.tabBar"
        static let queueTab = "queuePanel.tab.queue"
        static let recentlyPlayedTab = "queuePanel.tab.recentlyPlayed"
        static let historySection = "queuePanel.historySection"
        static let nowPlayingSection = "queuePanel.nowPlayingSection"
        static let upNextSection = "queuePanel.upNextSection"
        static let emptyState = "queuePanel.emptyState"

        static func historyRow(_ index: Int) -> String {
            "queuePanel.historyRow.\(index)"
        }

        static func upNextRow(_ index: Int) -> String {
            "queuePanel.upNextRow.\(index)"
        }

        static func removeButton(_ index: Int) -> String {
            "queuePanel.removeButton.\(index)"
        }
    }

    // MARK: - Now Playing Canvas

    enum NowPlayingCanvas {
        static let view = "nowPlayingCanvas.view"
        static let closeButton = "nowPlayingCanvas.closeButton"
        static let artwork = "nowPlayingCanvas.artwork"
        static let songTitle = "nowPlayingCanvas.songTitle"
        static let artistName = "nowPlayingCanvas.artistName"
        static let albumName = "nowPlayingCanvas.albumName"
        static let qualityBadge = "nowPlayingCanvas.qualityBadge"
    }

    // MARK: - Now Playing Banner

    enum NowPlayingBanner {
        static let songTitle = "nowPlayingBanner.songTitle"
        static let artistName = "nowPlayingBanner.artistName"
        static let albumName = "nowPlayingBanner.albumName"
        static let qualityBadge = "nowPlayingBanner.qualityBadge"
        static let albumArt = "nowPlayingBanner.albumArt"
    }

    // MARK: - Amp Settings

    enum AmpSettings {
        static let view = "ampSettings.view"
        static let powerButton = "ampSettings.powerButton"

        static func playerRow(_ pid: Int) -> String {
            "ampSettings.playerRow.\(pid)"
        }
    }

    // MARK: - Group Management

    enum Group {
        static let manageButton = "group.manageButton"
        static let popover = "group.popover"
        static let leaderPicker = "group.leaderPicker"
        static let createButton = "group.createButton"
        static let emptyState = "group.emptyState"

        static func ungroupButton(_ gid: Int) -> String {
            "group.ungroupButton.\(gid)"
        }

        static func memberToggle(_ pid: Int) -> String {
            "group.memberToggle.\(pid)"
        }
    }

    // MARK: - Toast

    enum Toast {
        static let view = "toast.view"
        static let message = "toast.message"
    }

    // MARK: - Input Selector

    enum InputSelector {
        static let grid = "inputSelector.grid"

        static func card(_ name: String) -> String {
            "inputSelector.card.\(name.lowercased().replacingOccurrences(of: " ", with: "_"))"
        }
    }

    // MARK: - Track List

    enum TrackList {
        static func row(_ index: Int) -> String {
            "trackList.row.\(index)"
        }
        static func title(_ index: Int) -> String {
            "trackList.title.\(index)"
        }
        static func artist(_ index: Int) -> String {
            "trackList.artist.\(index)"
        }
        static func album(_ index: Int) -> String {
            "trackList.album.\(index)"
        }
    }
}
