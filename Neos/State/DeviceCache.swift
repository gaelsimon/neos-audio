import Foundation
import NeosDomain
import os

private let cacheLogger = Logger(subsystem: "com.galela.neos", category: "cache")

struct CachedDevice: Codable {
    let device: DiscoveredDevice
    let selectedPlayerID: Int?

    /// Serial and device ID are stable; the host is a fallback, because a DHCP lease can move it.
    func matches(_ candidate: DiscoveredDevice) -> Bool {
        if !candidate.serialNumber.isEmpty, !device.serialNumber.isEmpty {
            return candidate.serialNumber == device.serialNumber
        }
        if !candidate.deviceID.isEmpty, !device.deviceID.isEmpty {
            return candidate.deviceID == device.deviceID
        }
        return candidate.host == device.host
    }
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
