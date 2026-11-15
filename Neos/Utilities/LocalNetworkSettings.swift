import Foundation
#if os(iOS)
import UIKit
#endif

/// Where the system keeps the app's local network permission, and how to say it.
enum LocalNetworkSettings {
    #if os(macOS)
    static let advice = "Allow Neos in System Settings › Privacy & Security › Local Network."
    static let buttonTitle = "Open System Settings"
    static let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_LocalNetwork")
    #else
    static let advice = "Allow Local Network for Neos in Settings."
    static let buttonTitle = "Open Settings"
    static let url = URL(string: UIApplication.openSettingsURLString)
    #endif
}
