import Foundation

/// Typed error for surface-level display in the UI.
/// Replaces raw `String?` error messaging with categorised cases
/// while keeping a `.generic` escape hatch for unstructured device strings.
public enum AppError: Error, Sendable, Equatable, CustomStringConvertible {
    /// Connection to the speaker failed or was lost.
    case connectionFailed(String)
    /// A playback command (play, pause, skip, etc.) could not complete.
    case playbackFailed(String)
    /// Queue operation failed (load, remove, clear, move).
    case queueFailed(String)
    /// Speaker grouping operation failed.
    case groupFailed(String)
    /// Account sign-in or sign-out failed.
    case accountFailed(String)
    /// Device discovery failed.
    case discoveryFailed(String)
    /// Power control command failed.
    case powerFailed(String)
    /// Device-reported error with no better classification.
    case deviceError(String)
    /// Catch-all for errors that don't fit a specific category.
    case generic(String)

    public var description: String {
        switch self {
        case .connectionFailed(let msg): msg
        case .playbackFailed(let msg):   msg
        case .queueFailed(let msg):      msg
        case .groupFailed(let msg):      msg
        case .accountFailed(let msg):    msg
        case .discoveryFailed(let msg):  msg
        case .powerFailed(let msg):      msg
        case .deviceError(let msg):      msg
        case .generic(let msg):          msg
        }
    }

    /// The user-facing message extracted from the associated value.
    public var message: String { description }
}
