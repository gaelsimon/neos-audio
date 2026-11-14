#if os(macOS)
import AppKit

typealias PlatformView = NSView
#else
import UIKit

typealias PlatformView = UIView
#endif
