import XCTest
@testable import HEOSKit

final class DeviceDiscoveryTests: XCTestCase {

    // MARK: - mergeDevices

    func testMergeSSDPOnlyReturnsUnchanged() {
        let ssdp = [
            DiscoveredDevice(host: "192.168.1.10", port: 1255, friendlyName: "Living Room", modelName: "HEOS 1", modelNumber: "DWS-1000", serialNumber: "SN123", location: "http://192.168.1.10:60006/upnp/desc/aios_device/aios_device.xml")
        ]
        let result = DeviceDiscovery.mergeDevices(ssdp: ssdp, bonjour: [])
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].host, "192.168.1.10")
        XCTAssertEqual(result[0].modelNumber, "DWS-1000")
        XCTAssertEqual(result[0].serialNumber, "SN123")
    }

    func testMergeBonjourOnlyUsesDefaultPort() {
        let bonjour = [
            DiscoveredDevice(host: "192.168.1.20", port: 9999, friendlyName: "Kitchen", modelName: "HEOS 3", firmwareVersion: "2.0.1", deviceID: "D001")
        ]
        let result = DeviceDiscovery.mergeDevices(ssdp: [], bonjour: bonjour)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].host, "192.168.1.20")
        // Bonjour-only devices get port 1255 (HEOS CLI default)
        XCTAssertEqual(result[0].port, 1255)
        XCTAssertEqual(result[0].friendlyName, "Kitchen")
    }

    func testMergeOverlappingKeepsSSDPPortAndMetadata() {
        let ssdp = [
            DiscoveredDevice(host: "192.168.1.30", port: 1255, friendlyName: "Bedroom", modelName: "HEOS 5", modelNumber: "DWS-5000", serialNumber: "SN555", location: "http://192.168.1.30:60006/desc.xml")
        ]
        let bonjour = [
            DiscoveredDevice(host: "192.168.1.30", port: 9999, friendlyName: "Bedroom Bonjour", modelName: "Bonjour Model", firmwareVersion: "3.1.0", deviceID: "BD30", networkID: "NET30")
        ]
        let result = DeviceDiscovery.mergeDevices(ssdp: ssdp, bonjour: bonjour)
        XCTAssertEqual(result.count, 1)
        let device = result[0]
        // SSDP port, modelNumber, serialNumber, location preserved
        XCTAssertEqual(device.port, 1255)
        XCTAssertEqual(device.modelNumber, "DWS-5000")
        XCTAssertEqual(device.serialNumber, "SN555")
        XCTAssertEqual(device.location, "http://192.168.1.30:60006/desc.xml")
        // SSDP friendlyName wins when non-empty
        XCTAssertEqual(device.friendlyName, "Bedroom")
        // Bonjour fields merged in
        XCTAssertEqual(device.firmwareVersion, "3.1.0")
        XCTAssertEqual(device.deviceID, "BD30")
        XCTAssertEqual(device.networkID, "NET30")
    }

    func testMergeSSDPEmptyNameFallsToBonjourName() {
        let ssdp = [
            DiscoveredDevice(host: "192.168.1.40", port: 1255, friendlyName: "", modelName: "")
        ]
        let bonjour = [
            DiscoveredDevice(host: "192.168.1.40", friendlyName: "Bonjour Name", modelName: "Bonjour Model")
        ]
        let result = DeviceDiscovery.mergeDevices(ssdp: ssdp, bonjour: bonjour)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].friendlyName, "Bonjour Name")
        XCTAssertEqual(result[0].modelName, "Bonjour Model")
    }

    func testMergeMultipleDevicesMixed() {
        let ssdp = [
            DiscoveredDevice(host: "192.168.1.10", port: 1255, friendlyName: "A"),
            DiscoveredDevice(host: "192.168.1.20", port: 1255, friendlyName: "B")
        ]
        let bonjour = [
            DiscoveredDevice(host: "192.168.1.20", friendlyName: "B-Bonjour", firmwareVersion: "1.0"),
            DiscoveredDevice(host: "192.168.1.30", friendlyName: "C-Bonjour", firmwareVersion: "2.0")
        ]
        let result = DeviceDiscovery.mergeDevices(ssdp: ssdp, bonjour: bonjour)
        XCTAssertEqual(result.count, 3)

        let hosts = Set(result.map(\.host))
        XCTAssertEqual(hosts, ["192.168.1.10", "192.168.1.20", "192.168.1.30"])

        // Bonjour-only device gets default port
        let deviceC = result.first { $0.host == "192.168.1.30" }!
        XCTAssertEqual(deviceC.port, 1255)
        XCTAssertEqual(deviceC.firmwareVersion, "2.0")
    }

    func testMergeEmptyInputsReturnsEmpty() {
        let result = DeviceDiscovery.mergeDevices(ssdp: [], bonjour: [])
        XCTAssertTrue(result.isEmpty)
    }

    func testMergeDuplicateSSDPHostLastWins() {
        let ssdp = [
            DiscoveredDevice(host: "192.168.1.10", port: 1255, friendlyName: "First"),
            DiscoveredDevice(host: "192.168.1.10", port: 1256, friendlyName: "Second")
        ]
        let result = DeviceDiscovery.mergeDevices(ssdp: ssdp, bonjour: [])
        XCTAssertEqual(result.count, 1)
        // Last SSDP entry for same host overwrites
        XCTAssertEqual(result[0].friendlyName, "Second")
        XCTAssertEqual(result[0].port, 1256)
    }
}
