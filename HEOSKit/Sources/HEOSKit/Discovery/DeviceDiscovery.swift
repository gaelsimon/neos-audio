import Foundation

public struct DeviceDiscovery: Sendable {
    private let ssdp = SSDPDiscovery()
    private let bonjour = BonjourDiscovery()

    public init() {}

    public func discover(timeout: TimeInterval = 5.0) async throws -> [DiscoveredDevice] {
        // Race SSDP and Bonjour concurrently, merge results by host IP
        async let ssdpDevices = discoverViaSSDP(timeout: timeout)
        async let bonjourDevices = bonjour.discover(timeout: timeout)

        let ssdpResults = await ssdpDevices
        let bonjourResults = await bonjourDevices

        return Self.mergeDevices(ssdp: ssdpResults, bonjour: bonjourResults)
    }

    private func discoverViaSSDP(timeout: TimeInterval) async -> [DiscoveredDevice] {
        guard let responses = try? await ssdp.search(timeout: timeout) else { return [] }

        return await withTaskGroup(of: DiscoveredDevice.self, returning: [DiscoveredDevice].self) { group in
            for response in responses {
                group.addTask {
                    await Self.enrichDevice(from: response)
                }
            }

            var devices: [DiscoveredDevice] = []
            for await device in group {
                devices.append(device)
            }
            return devices
        }
    }

    /// Merge SSDP and Bonjour results by host IP.
    /// SSDP provides the connection port (1255); Bonjour adds mDNS metadata.
    static func mergeDevices(ssdp: [DiscoveredDevice], bonjour: [DiscoveredDevice]) -> [DiscoveredDevice] {
        var byHost: [String: DiscoveredDevice] = [:]

        // SSDP first (has UPnP metadata: modelNumber, serialNumber, location, port)
        for device in ssdp {
            byHost[device.host] = device
        }

        // Bonjour adds mDNS-specific fields but keeps SSDP port
        for device in bonjour {
            if let existing = byHost[device.host] {
                byHost[existing.host] = DiscoveredDevice(
                    host: existing.host,
                    port: existing.port,
                    friendlyName: existing.friendlyName.isEmpty ? device.friendlyName : existing.friendlyName,
                    modelName: existing.modelName.isEmpty ? device.modelName : existing.modelName,
                    modelNumber: existing.modelNumber,
                    serialNumber: existing.serialNumber,
                    location: existing.location,
                    firmwareVersion: device.firmwareVersion,
                    deviceID: device.deviceID,
                    networkID: device.networkID
                )
            } else {
                // Bonjour-only device: use port 1255 for HEOS CLI
                byHost[device.host] = DiscoveredDevice(
                    host: device.host,
                    port: 1255,
                    friendlyName: device.friendlyName,
                    modelName: device.modelName,
                    firmwareVersion: device.firmwareVersion,
                    deviceID: device.deviceID,
                    networkID: device.networkID
                )
            }
        }

        return Array(byHost.values)
    }

    public static func enrichDevice(from response: SSDPResponse) async -> DiscoveredDevice {
        // Try to fetch UPnP XML for rich device info
        if let url = URL(string: response.location) {
            do {
                let (data, _) = try await HEOSURLSession.shared.data(from: url)
                if let xml = String(data: data, encoding: .utf8) {
                    let desc = UPnPDeviceDescription.parse(xml)
                    return DiscoveredDevice(
                        host: response.host,
                        port: 1255,
                        friendlyName: desc.friendlyName ?? response.host,
                        modelName: desc.modelName ?? "",
                        modelNumber: desc.modelNumber ?? "",
                        serialNumber: desc.serialNumber ?? "",
                        location: response.location
                    )
                }
            } catch {
                // Fall through to fallback
            }
        }

        // Fallback: use IP as friendly name
        return DiscoveredDevice(
            host: response.host,
            port: 1255,
            friendlyName: response.host,
            location: response.location
        )
    }
}

// MARK: - UPnP XML Parsing

enum UPnPDeviceDescription {
    struct Result {
        let friendlyName: String?
        let modelName: String?
        let modelNumber: String?
        let serialNumber: String?
    }

    static func parse(_ xml: String) -> Result {
        Result(
            friendlyName: extractTag("friendlyName", from: xml),
            modelName: extractTag("modelName", from: xml),
            modelNumber: extractTag("modelNumber", from: xml),
            serialNumber: extractTag("serialNumber", from: xml)
        )
    }

    static func extractTag(_ tag: String, from xml: String) -> String? {
        let open = "<\(tag)>"
        let close = "</\(tag)>"
        guard let openRange = xml.range(of: open),
              let closeRange = xml.range(of: close, range: openRange.upperBound..<xml.endIndex) else {
            return nil
        }
        let value = String(xml[openRange.upperBound..<closeRange.lowerBound])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}
