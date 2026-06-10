import Foundation
import Testing
@testable import HEOSKit

// MARK: - Time Format Conversion Tests

@Suite("UPnP Time Format Tests")
struct UPnPTimeFormatTests {

    @Test func toSecondsTypicalDuration() {
        #expect(UPnPTimeFormat.toSeconds("0:04:32") == 272)
    }

    @Test func toSecondsWithHours() {
        #expect(UPnPTimeFormat.toSeconds("1:30:00") == 5400)
    }

    @Test func toSecondsZero() {
        #expect(UPnPTimeFormat.toSeconds("0:00:00") == 0)
    }

    @Test func toSecondsDoubleDigitHours() {
        #expect(UPnPTimeFormat.toSeconds("12:00:00") == 43200)
    }

    @Test func toSecondsNotImplemented() {
        #expect(UPnPTimeFormat.toSeconds("NOT_IMPLEMENTED") == nil)
    }

    @Test func toSecondsEmptyString() {
        #expect(UPnPTimeFormat.toSeconds("") == nil)
    }

    @Test func toSecondsInvalidFormat() {
        #expect(UPnPTimeFormat.toSeconds("abc") == nil)
        #expect(UPnPTimeFormat.toSeconds("1:2") == nil)
        #expect(UPnPTimeFormat.toSeconds("::") == nil)
    }

    @Test func fromSecondsTypical() {
        #expect(UPnPTimeFormat.fromSeconds(84) == "0:01:24")
    }

    @Test func fromSecondsZero() {
        #expect(UPnPTimeFormat.fromSeconds(0) == "0:00:00")
    }

    @Test func fromSecondsWithHours() {
        #expect(UPnPTimeFormat.fromSeconds(5400) == "1:30:00")
    }

    @Test func fromSecondsNegativeClampsToZero() {
        #expect(UPnPTimeFormat.fromSeconds(-10) == "0:00:00")
    }

    @Test func fromSecondsTruncatesFractional() {
        #expect(UPnPTimeFormat.fromSeconds(84.7) == "0:01:24")
    }

    @Test func roundTrip() {
        let original: TimeInterval = 3723 // 1:02:03
        let formatted = UPnPTimeFormat.fromSeconds(original)
        let parsed = UPnPTimeFormat.toSeconds(formatted)
        #expect(parsed == original)
    }
}

// MARK: - SOAP Envelope Tests

@Suite("SOAP Envelope Tests")
struct SOAPEnvelopeTests {

    @Test func seekRequestContainsAction() {
        let data = SOAPEnvelope.request(action: "Seek", arguments: [
            ("Unit", "REL_TIME"),
            ("Target", "0:01:24"),
        ])
        let xml = String(decoding: data, as: UTF8.self)

        #expect(xml.contains("<u:Seek xmlns:u=\"urn:schemas-upnp-org:service:AVTransport:1\">"))
        #expect(xml.contains("<InstanceID>0</InstanceID>"))
        #expect(xml.contains("<Unit>REL_TIME</Unit>"))
        #expect(xml.contains("<Target>0:01:24</Target>"))
        #expect(xml.contains("</u:Seek>"))
    }

    @Test func getPositionInfoRequestHasNoExtraArgs() {
        let data = SOAPEnvelope.request(action: "GetPositionInfo")
        let xml = String(decoding: data, as: UTF8.self)

        #expect(xml.contains("<u:GetPositionInfo xmlns:u="))
        #expect(xml.contains("<InstanceID>0</InstanceID>"))
        #expect(xml.contains("</u:GetPositionInfo>"))
    }

    @Test func soapActionHeader() {
        let header = SOAPEnvelope.soapAction("Seek")
        #expect(header == "\"urn:schemas-upnp-org:service:AVTransport:1#Seek\"")
    }

    @Test func envelopeIsValidXML() {
        let data = SOAPEnvelope.request(action: "Stop")
        let xml = String(decoding: data, as: UTF8.self)

        #expect(xml.hasPrefix("<?xml version=\"1.0\" encoding=\"utf-8\"?>"))
        #expect(xml.contains("<s:Envelope"))
        #expect(xml.contains("</s:Envelope>"))
        #expect(xml.contains("<s:Body>"))
        #expect(xml.contains("</s:Body>"))
    }

    @Test func customServiceType() {
        let actType = "urn:schemas-denon-com:service:ACT:1"
        let data = SOAPEnvelope.request(
            action: "GetVolumeLimit",
            serviceType: actType,
            includeInstanceID: false
        )
        let xml = String(decoding: data, as: UTF8.self)

        #expect(xml.contains("xmlns:u=\"\(actType)\""))
        #expect(!xml.contains("InstanceID"))
        #expect(xml.contains("<u:GetVolumeLimit"))
        #expect(xml.contains("</u:GetVolumeLimit>"))
    }

    @Test func customServiceTypeSoapAction() {
        let actType = "urn:schemas-denon-com:service:ACT:1"
        let header = SOAPEnvelope.soapAction("GetVolumeLimit", serviceType: actType)
        #expect(header == "\"\(actType)#GetVolumeLimit\"")
    }
}

// MARK: - SOAP Response Parsing Tests

@Suite("SOAP Response Parsing Tests")
struct SOAPResponseParsingTests {

    @Test func extractTagFindsValue() {
        let xml = "<Track>1</Track><RelTime>0:01:24</RelTime>"
        #expect(SOAPEnvelope.extractTag("Track", from: xml) == "1")
        #expect(SOAPEnvelope.extractTag("RelTime", from: xml) == "0:01:24")
    }

    @Test func extractTagMissingTag() {
        #expect(SOAPEnvelope.extractTag("Missing", from: "<Other>val</Other>") == nil)
    }

    @Test func extractTagEmptyValue() {
        #expect(SOAPEnvelope.extractTag("Empty", from: "<Empty></Empty>") == nil)
    }

    @Test func extractTagWhitespaceOnly() {
        #expect(SOAPEnvelope.extractTag("Spaces", from: "<Spaces>   </Spaces>") == nil)
    }

    @Test func parseFaultExtractsCodeAndDescription() {
        let xml = """
        <s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/">
        <s:Body>
        <s:Fault>
        <faultcode>s:Client</faultcode>
        <faultstring>UPnPError</faultstring>
        <detail>
        <UPnPError xmlns="urn:schemas-upnp-org:control-1-0">
        <errorCode>701</errorCode>
        <errorDescription>Transition not available</errorDescription>
        </UPnPError>
        </detail>
        </s:Fault>
        </s:Body>
        </s:Envelope>
        """

        let fault = SOAPEnvelope.parseFault(from: xml)
        #expect(fault != nil)
        if case .soapFault(let code, let desc) = fault {
            #expect(code == 701)
            #expect(desc == "Transition not available")
        } else {
            Issue.record("Expected soapFault case")
        }
    }

    @Test func parseFaultReturnsNilForSuccess() {
        let xml = """
        <s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/">
        <s:Body>
        <u:SeekResponse xmlns:u="urn:schemas-upnp-org:service:AVTransport:1">
        </u:SeekResponse>
        </s:Body>
        </s:Envelope>
        """

        #expect(SOAPEnvelope.parseFault(from: xml) == nil)
    }
}

// MARK: - PositionInfo Model Tests

@Suite("PositionInfo Tests")
struct PositionInfoTests {

    @Test func computedDuration() {
        let info = PositionInfo(
            track: 1,
            trackDuration: "0:04:32",
            relTime: "0:01:24",
            trackURI: nil,
            trackMetaData: nil
        )
        #expect(info.duration == 272)
        #expect(info.position == 84)
    }

    @Test func computedMillis() {
        let info = PositionInfo(
            track: 1,
            trackDuration: "0:04:32",
            relTime: "0:01:24",
            trackURI: nil,
            trackMetaData: nil
        )
        #expect(info.durationMillis == 272000)
        #expect(info.positionMillis == 84000)
    }

    @Test func notImplementedReturnsNil() {
        let info = PositionInfo(
            track: 1,
            trackDuration: "NOT_IMPLEMENTED",
            relTime: "NOT_IMPLEMENTED",
            trackURI: nil,
            trackMetaData: nil
        )
        #expect(info.duration == nil)
        #expect(info.position == nil)
        #expect(info.durationMillis == nil)
        #expect(info.positionMillis == nil)
    }

    @Test func equality() {
        let a = PositionInfo(track: 1, trackDuration: "0:04:32", relTime: "0:01:24", trackURI: "x", trackMetaData: nil)
        let b = PositionInfo(track: 1, trackDuration: "0:04:32", relTime: "0:01:24", trackURI: "x", trackMetaData: nil)
        #expect(a == b)
    }
}

// MARK: - UPnPError Tests

@Suite("UPnPError Tests")
struct UPnPErrorTests {

    @Test func httpErrorDescription() {
        let error = UPnPError.httpError(statusCode: 404)
        #expect(error.localizedDescription.contains("404"))
    }

    @Test func soapFaultDescription() {
        let error = UPnPError.soapFault(code: 701, description: "Transition not available")
        #expect(error.localizedDescription.contains("701"))
        #expect(error.localizedDescription.contains("Transition not available"))
    }

    @Test func invalidResponseDescription() {
        let error = UPnPError.invalidResponse
        #expect(!error.localizedDescription.isEmpty)
    }

}
