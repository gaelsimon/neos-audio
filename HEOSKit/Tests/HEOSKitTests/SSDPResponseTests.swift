import Testing
@testable import HEOSKit

@Suite("SSDPResponse Parsing Tests")
struct SSDPResponseTests {

    @Test func parseValidResponse() {
        let response = "HTTP/1.1 200 OK\r\n"
            + "CACHE-CONTROL: max-age=180\r\n"
            + "LOCATION: http://192.168.1.100:60006/upnp/desc/aios_device/aios_device.xml\r\n"
            + "SERVER: Linux/3.14.29 UPnP/1.0 HEOS/1.520.200\r\n"
            + "ST: urn:schemas-denon-com:device:ACT-Denon:1\r\n"
            + "USN: uuid:12345678-1234-1234-1234-123456789abc\r\n"
            + "\r\n"

        let parsed = SSDPResponse.parse(response)
        #expect(parsed != nil)
        #expect(parsed?.location == "http://192.168.1.100:60006/upnp/desc/aios_device/aios_device.xml")
        #expect(parsed?.host == "192.168.1.100")
        #expect(parsed?.st == "urn:schemas-denon-com:device:ACT-Denon:1")
        #expect(parsed?.server.contains("HEOS") == true)
    }

    @Test func parseMissingLocation() {
        let response = "HTTP/1.1 200 OK\r\n"
            + "SERVER: Linux/3.14.29 UPnP/1.0 HEOS/1.520.200\r\n"
            + "ST: urn:schemas-denon-com:device:ACT-Denon:1\r\n"
            + "\r\n"

        let parsed = SSDPResponse.parse(response)
        #expect(parsed == nil)
    }

    @Test func extractHostFromLocation() {
        let response = "HTTP/1.1 200 OK\r\n"
            + "LOCATION: http://10.0.0.50:8080/device.xml\r\n"
            + "\r\n"

        let parsed = SSDPResponse.parse(response)
        #expect(parsed?.host == "10.0.0.50")
    }
}

// MARK: - SSDPError Tests

@Suite("SSDPError Description Tests")
struct SSDPErrorTests {

    @Test func socketCreationFailedDescription() {
        let error = SSDPError.socketCreationFailed(errno: 24, detail: "Too many open files")
        #expect(error.description.contains("errno 24"))
        #expect(error.description.contains("Too many open files"))
    }

    @Test func socketOptionFailedDescription() {
        let error = SSDPError.socketOptionFailed(option: "SO_REUSEPORT", errno: 22, detail: "Invalid argument")
        #expect(error.description.contains("SO_REUSEPORT"))
        #expect(error.description.contains("errno 22"))
    }

    @Test func sendFailedDescription() {
        let error = SSDPError.sendFailed(errno: 65, detail: "No route to host")
        #expect(error.description.contains("errno 65"))
        #expect(error.description.contains("No route to host"))
    }

    @Test func bindFailedDescription() {
        let error = SSDPError.bindFailed(errno: 48, detail: "Address already in use")
        #expect(error.description.contains("errno 48"))
        #expect(error.description.contains("Address already in use"))
    }

    @Test func timeoutDescription() {
        let error = SSDPError.timeout
        #expect(error.description.contains("timed out"))
    }
}

// MARK: - M-SEARCH Message Format Tests

@Suite("M-SEARCH Message Format Tests")
struct MSearchMessageTests {

    @Test func messageStartsWithMSearch() {
        #expect(SSDPDiscovery.mSearchMessage.hasPrefix("M-SEARCH * HTTP/1.1\r\n"))
    }

    @Test func messageContainsProperHost() {
        #expect(SSDPDiscovery.mSearchMessage.contains("HOST: 239.255.255.250:1900\r\n"))
    }

    @Test func messageContainsSearchTarget() {
        #expect(SSDPDiscovery.mSearchMessage.contains("ST: urn:schemas-denon-com:device:ACT-Denon:1\r\n"))
    }

    @Test func messageEndsWithBlankLine() {
        #expect(SSDPDiscovery.mSearchMessage.hasSuffix("\r\n\r\n"))
    }

    @Test func messageHasNoLeadingWhitespace() {
        let lines = SSDPDiscovery.mSearchMessage.components(separatedBy: "\r\n")
        for line in lines where !line.isEmpty {
            #expect(!line.hasPrefix(" "), "Line should not start with space: '\(line)'")
            #expect(!line.hasPrefix("\t"), "Line should not start with tab: '\(line)'")
        }
    }

    @Test func messageUsesCRLF() {
        // Every line ending should be \r\n, not bare \n
        let withoutCRLF = SSDPDiscovery.mSearchMessage.replacingOccurrences(of: "\r\n", with: "")
        #expect(!withoutCRLF.contains("\n"), "Message should not contain bare \\n line endings")
    }
}

// MARK: - UPnP XML Parsing Tests

@Suite("UPnP XML Parsing Tests")
struct UPnPParsingTests {

    @Test func parseTypicalXML() {
        let xml = """
        <?xml version="1.0"?>
        <root xmlns="urn:schemas-upnp-org:device-1-0">
          <device>
            <friendlyName>Marantz MODEL 40N</friendlyName>
            <modelName>MODEL 40N</modelName>
            <modelNumber>40N</modelNumber>
            <serialNumber>ABC123456</serialNumber>
          </device>
        </root>
        """

        let result = UPnPDeviceDescription.parse(xml)
        #expect(result.friendlyName == "Marantz MODEL 40N")
        #expect(result.modelName == "MODEL 40N")
        #expect(result.modelNumber == "40N")
        #expect(result.serialNumber == "ABC123456")
    }

    @Test func parseMissingTags() {
        let xml = """
        <?xml version="1.0"?>
        <root>
          <device>
            <friendlyName>My Speaker</friendlyName>
          </device>
        </root>
        """

        let result = UPnPDeviceDescription.parse(xml)
        #expect(result.friendlyName == "My Speaker")
        #expect(result.modelName == nil)
        #expect(result.modelNumber == nil)
        #expect(result.serialNumber == nil)
    }

    @Test func parseEmptyInput() {
        let result = UPnPDeviceDescription.parse("")
        #expect(result.friendlyName == nil)
        #expect(result.modelName == nil)
        #expect(result.modelNumber == nil)
        #expect(result.serialNumber == nil)
    }

    @Test func parseEmptyTagValue() {
        let xml = "<friendlyName></friendlyName>"
        let result = UPnPDeviceDescription.parse(xml)
        #expect(result.friendlyName == nil)
    }

    @Test func extractTag() {
        #expect(UPnPDeviceDescription.extractTag("foo", from: "<foo>bar</foo>") == "bar")
        #expect(UPnPDeviceDescription.extractTag("foo", from: "<baz>bar</baz>") == nil)
        #expect(UPnPDeviceDescription.extractTag("foo", from: "") == nil)
    }
}
