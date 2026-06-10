import Foundation
import AppKit
import NeosDomain

@Observable
@MainActor
final class SettingsViewModel {
    private let state: AppState

    // MARK: - Volume Limit

    var volumeLimitEnabled: Bool {
        didSet {
            if volumeLimitEnabled {
                state.playback.maxVolume = volumeLimitValue
            } else {
                state.playback.maxVolume = nil
            }
            UserDefaults.standard.set(volumeLimitEnabled, forKey: "settings.volumeLimitEnabled")
        }
    }

    var volumeLimitValue: Int {
        didSet {
            let clamped = max(1, min(100, volumeLimitValue))
            if clamped != volumeLimitValue { volumeLimitValue = clamped }
            if volumeLimitEnabled {
                state.playback.maxVolume = clamped
            }
            UserDefaults.standard.set(clamped, forKey: "settings.volumeLimitValue")
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
        let imageDiskBytes = ImageCache.shared.diskSizeBytes()
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
        ImageCache.shared.clearAll()
    }

    // MARK: - Diagnostics

    func copyDiagnostics() {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        let lines = state.diagnostics.map { event in
            "[\(formatter.string(from: event.date))] [\(event.source)] \(event.message)"
        }
        let text = lines.joined(separator: "\n")
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text.isEmpty ? "No diagnostic events" : text, forType: .string)
    }

    // MARK: - Init

    init(state: AppState) {
        self.state = state
        self.volumeLimitEnabled = UserDefaults.standard.bool(forKey: "settings.volumeLimitEnabled")
        let savedValue = UserDefaults.standard.integer(forKey: "settings.volumeLimitValue")
        self.volumeLimitValue = savedValue > 0 ? savedValue : 80

        // Apply persisted limit on launch
        if volumeLimitEnabled {
            state.playback.maxVolume = volumeLimitValue
        }
    }
}
