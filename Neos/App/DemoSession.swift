import Foundation

// Demo mode is a launch option for UI tests and screenshots; it never touches the user's Keychain.
enum DemoSession {
    #if DEBUG
    static let isActive = CommandLine.arguments.contains("--demo-mode")
    #else
    static let isActive = false
    #endif
}
