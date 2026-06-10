import Testing
@testable import HEOSKit

@Suite("HEOSMessageParser Tests")
struct HEOSMessageParserTests {
    let parser = HEOSMessageParser()

    @Test func emptyMessage() {
        let result = parser.parse("")
        #expect(result.isEmpty)
    }

    @Test func singleKeyValue() {
        let result = parser.parse("pid=123")
        #expect(result == ["pid": "123"])
    }

    @Test func multipleKeyValues() {
        let result = parser.parse("pid=123&state=play&level=50")
        #expect(result["pid"] == "123")
        #expect(result["state"] == "play")
        #expect(result["level"] == "50")
    }

    @Test func decodesAmpersand() {
        let result = parser.parse("name=Rock%26Roll")
        #expect(result["name"] == "Rock&Roll")
    }

    @Test func decodesEquals() {
        let result = parser.parse("title=A%3DB")
        #expect(result["title"] == "A=B")
    }

    @Test func decodesPercent() {
        let result = parser.parse("val=100%25")
        #expect(result["val"] == "100%")
    }

    @Test func keyWithoutValue() {
        let result = parser.parse("signed_out")
        #expect(result["signed_out"] == "")
    }

    @Test func errorMessage() {
        let result = parser.parse("eid=2&text=Invalid ID")
        #expect(result["eid"] == "2")
        #expect(result["text"] == "Invalid ID")
    }

    @Test func playerVolumeChangedMessage() {
        let result = parser.parse("pid=123456&level=45&mute=off")
        #expect(result["pid"] == "123456")
        #expect(result["level"] == "45")
        #expect(result["mute"] == "off")
    }

    @Test func progressMessage() {
        let result = parser.parse("pid=123&cur_pos=60000&duration=240000")
        #expect(result["cur_pos"] == "60000")
        #expect(result["duration"] == "240000")
    }

    @Test func decodesURLInMid() {
        let result = parser.parse("mid=https%3A%2F%2Ficecast.radiofrance.fr%2Ffip-hifi.aac")
        #expect(result["mid"] == "https://icecast.radiofrance.fr/fip-hifi.aac")
    }

    @Test func decodesSpaceAndPlus() {
        let result = parser.parse("name=FIP%20Radio&tag=rock%2Bjazz")
        #expect(result["name"] == "FIP Radio")
        #expect(result["tag"] == "rock+jazz")
    }

    @Test func decodesQuestionAndHash() {
        let result = parser.parse("url=http%3A%2F%2Fexample.com%2Fstream%3Ffmt%3Daac%23v2")
        #expect(result["url"] == "http://example.com/stream?fmt=aac#v2")
    }
}
