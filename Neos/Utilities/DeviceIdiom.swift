#if os(iOS)
import UIKit
#endif

/// The device, not the window: rotating or resizing must not swap the player's presentation or move the
/// mini player under the user.
enum DeviceIdiom {
    static var isPad: Bool {
        #if os(iOS)
        UIDevice.current.userInterfaceIdiom == .pad
        #else
        false
        #endif
    }

    /// What a sentence calls the device.
    static var name: String {
        #if os(iOS)
        isPad ? "iPad" : "iPhone"
        #else
        "Mac"
        #endif
    }
}
