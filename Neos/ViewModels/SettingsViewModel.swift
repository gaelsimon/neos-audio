import Foundation
import NeosDomain

@Observable
@MainActor
final class SettingsViewModel {
    private let state: AppState
    private let defaults: UserDefaults
    /// The image cache and the clipboard are the app's own; tests hand in their stand-ins.
    private let imageCacheBytes: () -> Int
    private let clearImageCache: () -> Void
    private let copyText: @MainActor (String) -> Void

    // MARK: - Volume Limit

    var volumeLimitEnabled: Bool {
        didSet {
            if volumeLimitEnabled {
                state.playback.volumeLimit = volumeLimitValue
            } else {
                state.playback.volumeLimit = nil
            }
            defaults.set(volumeLimitEnabled, forKey: "settings.volumeLimitEnabled")
        }
    }

    var volumeLimitValue: Int {
        didSet {
            let clamped = max(1, min(100, volumeLimitValue))
            if clamped != volumeLimitValue { volumeLimitValue = clamped }
            if volumeLimitEnabled {
                state.playback.volumeLimit = clamped
            }
            defaults.set(clamped, forKey: "settings.volumeLimitValue")
        }
    }

    // MARK: - Cache

    var estimatedCacheSize: String {
        var parts: [String] = []
        if state.trackMetadata != nil {
            parts.append("track metadata")
        }
        if !state.serviceCapabilities.isEmpty {
            parts.append("\(state.serviceCapabilities.count) service capabilities")
        }
        if !state.searchCriteria.isEmpty {
            parts.append("\(state.searchCriteria.count) search criteria")
        }
        if !state.diagnostics.isEmpty {
            parts.append("\(state.diagnostics.count) diagnostic events")
        }
        let imageDiskBytes = imageCacheBytes()
        if imageDiskBytes > 0 {
            parts.append("\(ByteCountFormatter.string(fromByteCount: Int64(imageDiskBytes), countStyle: .file)) images")
        }
        if parts.isEmpty { return "Empty" }
        return parts.joined(separator: ", ").prefix(1).uppercased() + parts.joined(separator: ", ").dropFirst()
    }

    var showClearCacheConfirmation: Bool = false

    func clearCache() {
        state.playback.trackMetadata = nil
        state.serviceCapabilities = [:]
        state.searchCriteria = [:]
        state.diagnostics = []
        clearImageCache()
    }

    // MARK: - Diagnostics

    func copyDiagnostics() {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        let lines = state.diagnostics.map { event in
            "[\(formatter.string(from: event.date))] [\(event.source)] \(event.message)"
        }
        let text = lines.joined(separator: "\n")
        copyText(text.isEmpty ? "No diagnostic events" : text)
    }

    // MARK: - Init

    init(
        state: AppState,
        defaults: UserDefaults = AppDefaults.store,
        imageCacheBytes: @escaping () -> Int = { ImageCache.shared.diskSizeBytes() },
        clearImageCache: @escaping () -> Void = { ImageCache.shared.clearAll() },
        copyText: @escaping @MainActor (String) -> Void = { Clipboard.copy($0) }
    ) {
        self.state = state
        self.defaults = defaults
        self.imageCacheBytes = imageCacheBytes
        self.clearImageCache = clearImageCache
        self.copyText = copyText
        self.volumeLimitEnabled = defaults.bool(forKey: "settings.volumeLimitEnabled")
        let savedValue = defaults.integer(forKey: "settings.volumeLimitValue")
        self.volumeLimitValue = savedValue > 0 ? savedValue : 80

        // Apply persisted limit on launch
        if volumeLimitEnabled {
            state.playback.volumeLimit = volumeLimitValue
        }
    }
}
