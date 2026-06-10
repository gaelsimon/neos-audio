import Foundation

/// Rich track metadata parsed from UPnP DIDL-Lite XML.
/// All fields are optional; availability depends on the streaming source and device.
public struct TrackMetadata: Sendable, Equatable {
    // Audio quality
    public let sampleRate: Int?      // Hz (e.g. 44100, 96000, 192000)
    public let bitDepth: Int?        // bits (e.g. 16, 24)
    public let channels: Int?        // e.g. 2 for stereo
    public let bitrate: Int?         // bits/sec
    public let codec: String?        // e.g. "FLAC", "AAC", "MP3"

    // Track info
    public let genre: String?
    public let trackNumber: Int?

    // Possibly higher-res album art
    public let albumArtURI: String?

    public init(
        sampleRate: Int? = nil,
        bitDepth: Int? = nil,
        channels: Int? = nil,
        bitrate: Int? = nil,
        codec: String? = nil,
        genre: String? = nil,
        trackNumber: Int? = nil,
        albumArtURI: String? = nil
    ) {
        self.sampleRate = sampleRate
        self.bitDepth = bitDepth
        self.channels = channels
        self.bitrate = bitrate
        self.codec = codec
        self.genre = genre
        self.trackNumber = trackNumber
        self.albumArtURI = albumArtURI
    }

    /// Human-readable audio quality string, e.g. "24-bit / 96 kHz FLAC".
    /// Returns nil if no audio quality info is available.
    public var qualityDescription: String? {
        var parts: [String] = []

        if let bitDepth {
            parts.append("\(bitDepth)-bit")
        }

        if let sampleRate {
            let kHz = Double(sampleRate) / 1000.0
            if kHz == kHz.rounded() {
                parts.append("\(Int(kHz)) kHz")
            } else {
                parts.append(String(format: "%.1f kHz", kHz))
            }
        }

        guard !parts.isEmpty else { return nil }

        var result = parts.joined(separator: " / ")
        if let codec {
            result += " \(codec)"
        }
        return result
    }
}
