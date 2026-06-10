import Foundation
import NeosDomain
import os

private let cacheLogger = Logger(subsystem: "com.galela.neos", category: "cache")

struct CachedDevice: Codable {
    let device: DiscoveredDevice
    let selectedPlayerID: Int?
}

enum DeviceCache {
    private static let key = "lastConnectedDevice"

    static func save(device: DiscoveredDevice, selectedPlayerID: Int?) {
        let cached = CachedDevice(device: device, selectedPlayerID: selectedPlayerID)
        do {
            let data = try JSONEncoder().encode(cached)
            UserDefaults.standard.set(data, forKey: key)
        } catch {
            cacheLogger.warning("Failed to encode device cache: \(error.localizedDescription)")
        }
    }

    static func load() -> CachedDevice? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        do {
            return try JSONDecoder().decode(CachedDevice.self, from: data)
        } catch {
            cacheLogger.warning("Failed to decode device cache: \(error.localizedDescription)")
            return nil
        }
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}
