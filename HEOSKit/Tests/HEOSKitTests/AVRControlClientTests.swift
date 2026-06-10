import Testing
@testable import HEOSKit

@Suite("AVRControlClient Tests")
struct AVRControlClientTests {

    // MARK: - MVMAX Parsing

    @Test func parseMaxVolume_standard80() {
        // AVR 80 = 0 dB → HEOS ~82
        let result = AVRControlClient.parseMaxVolume(from: "MVMAX 80")
        #expect(result == 82)
    }

    @Test func parseMaxVolume_threeDigitResponse() {
        // "MVMAX 805" means 80.5; takes first 2 digits (80) → HEOS 82
        let result = AVRControlClient.parseMaxVolume(from: "MVMAX 805")
        #expect(result == 82)
    }

    @Test func parseMaxVolume_fullRange98() {
        // AVR 98 = +18 dB → HEOS 100
        let result = AVRControlClient.parseMaxVolume(from: "MVMAX 98")
        #expect(result == 100)
    }

    @Test func parseMaxVolume_lowerLimit60() {
        // AVR 60 → HEOS 61 (60/98*100 = 61.2, rounded to 61)
        let result = AVRControlClient.parseMaxVolume(from: "MVMAX 60")
        #expect(result == 61)
    }

    @Test func parseMaxVolume_zero() {
        // AVR 0 → HEOS 0
        let result = AVRControlClient.parseMaxVolume(from: "MVMAX 00")
        #expect(result == 0)
    }

    @Test func parseMaxVolume_nonMatchingMessage() {
        #expect(AVRControlClient.parseMaxVolume(from: "PWON") == nil)
        #expect(AVRControlClient.parseMaxVolume(from: "MV50") == nil)
        #expect(AVRControlClient.parseMaxVolume(from: "") == nil)
    }

    @Test func parseMaxVolume_malformedValue() {
        #expect(AVRControlClient.parseMaxVolume(from: "MVMAX abc") == nil)
        #expect(AVRControlClient.parseMaxVolume(from: "MVMAX ") == nil)
    }
}
