import os

enum HEOSLogger {
    static let connection = Logger(subsystem: "com.galela.neos.HEOSKit", category: "connection")
    static let transport = Logger(subsystem: "com.galela.neos.HEOSKit", category: "transport")
    static let service = Logger(subsystem: "com.galela.neos.HEOSKit", category: "service")
    static let discovery = Logger(subsystem: "com.galela.neos.HEOSKit", category: "discovery")
    static let avr = Logger(subsystem: "com.galela.neos.HEOSKit", category: "avr")
    static let upnp = Logger(subsystem: "com.galela.neos.HEOSKit", category: "upnp")
}
