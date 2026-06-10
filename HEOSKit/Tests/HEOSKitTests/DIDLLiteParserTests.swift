import Foundation
import Testing
@testable import HEOSKit

@Suite("DIDLLiteParser Tests")
struct DIDLLiteParserTests {

    // MARK: - Full DIDL-Lite parsing

    static let fullDIDL = """
    <DIDL-Lite xmlns:dc="http://purl.org/dc/elements/1.1/"
               xmlns:upnp="urn:schemas-upnp-org:metadata-1-0/upnp/"
               xmlns="urn:schemas-upnp-org:metadata-1-0/DIDL-Lite/">
      <item>
        <dc:title>Giant Steps</dc:title>
        <dc:creator>John Coltrane</dc:creator>
        <upnp:artist>John Coltrane</upnp:artist>
        <upnp:album>Giant Steps</upnp:album>
        <upnp:genre>Jazz</upnp:genre>
        <upnp:originalTrackNumber>1</upnp:originalTrackNumber>
        <upnp:albumArtURI>http://example.com/art.jpg</upnp:albumArtURI>
        <res protocolInfo="http-get:*:audio/flac:*"
             sampleFrequency="96000"
             bitsPerSample="24"
             nrAudioChannels="2"
             bitrate="4608000"
             duration="0:04:46">http://example.com/stream</res>
      </item>
    </DIDL-Lite>
    """

    @Test func parsesFullDIDLLite() {
        let metadata = DIDLLiteParser.parse(Self.fullDIDL)
        #expect(metadata != nil)
        #expect(metadata?.sampleRate == 96000)
        #expect(metadata?.bitDepth == 24)
        #expect(metadata?.channels == 2)
        #expect(metadata?.bitrate == 4608000)
        #expect(metadata?.codec == "FLAC")
        #expect(metadata?.genre == "Jazz")
        #expect(metadata?.trackNumber == 1)
        #expect(metadata?.albumArtURI == "http://example.com/art.jpg")
    }

    // MARK: - Real Marantz/Tidal response (from GetCurrentState)

    @Test func parsesRealTidalResponse() {
        // Actual DIDL-Lite from a Marantz MODEL 40n playing Tidal via GetCurrentState.
        // Key differences from ideal: wildcard MIME type, Denon audioFormat desc, empty genre.
        let tidalDIDL = """
        <DIDL-Lite xmlns="urn:schemas-upnp-org:metadata-1-0/DIDL-Lite/" \
        xmlns:dc="http://purl.org/dc/elements/1.1/" \
        xmlns:upnp="urn:schemas-upnp-org:metadata-1-0/upnp/">
        <item id="460096207" parentID="460096206" restricted="1">
        <dc:title>how long will it take to walk a mile?</dc:title>
        <res protocolInfo="http-get:*:*:DLNA.ORG_OP=11;DLNA.ORG_CI=0;DLNA.ORG_FLAGS=00000000000000000000000000000000" \
        size="0" sampleFrequency="48000" bitsPerSample="24" duration="00:00:36">\
        aiosws://tidal/track/460096207</res>
        <desc id="audioFormat" nameSpace="urn:schemas-denon-com:metadata/" \
        xmlns:aios="urn:schemas-denon-com:metadata/">FLAC</desc>
        <upnp:genre>&quot;&quot;</upnp:genre>
        <dc:creator>Lola Young</dc:creator>
        <upnp:artist>Lola Young</upnp:artist>
        <upnp:album>Album Name</upnp:album>
        <upnp:albumArtURI>http://resources.wimpmusic.com/images/art.jpg</upnp:albumArtURI>
        </item></DIDL-Lite>
        """

        let metadata = DIDLLiteParser.parse(tidalDIDL)
        #expect(metadata != nil)
        #expect(metadata?.sampleRate == 48000)
        #expect(metadata?.bitDepth == 24)
        #expect(metadata?.codec == "FLAC")
        #expect(metadata?.genre == nil) // "" placeholder is filtered out
        #expect(metadata?.albumArtURI == "http://resources.wimpmusic.com/images/art.jpg")
        #expect(metadata?.qualityDescription == "24-bit / 48 kHz FLAC")
    }

    // MARK: - Denon audioFormat descriptor as codec fallback

    @Test func usesAudioFormatDescWhenMIMEIsWildcard() {
        let xml = """
        <DIDL-Lite xmlns="urn:schemas-upnp-org:metadata-1-0/DIDL-Lite/"
                   xmlns:dc="http://purl.org/dc/elements/1.1/">
          <item>
            <dc:title>Test</dc:title>
            <res protocolInfo="http-get:*:*:DLNA.ORG_OP=11"
                 sampleFrequency="96000"
                 bitsPerSample="24">http://stream</res>
            <desc id="audioFormat" nameSpace="urn:schemas-denon-com:metadata/"
                  xmlns:aios="urn:schemas-denon-com:metadata/">flac</desc>
          </item>
        </DIDL-Lite>
        """

        let metadata = DIDLLiteParser.parse(xml)
        #expect(metadata?.codec == "FLAC")
        #expect(metadata?.sampleRate == 96000)
        #expect(metadata?.bitDepth == 24)
    }

    @Test func prefersProtocolInfoOverAudioFormatDesc() {
        let xml = """
        <DIDL-Lite xmlns="urn:schemas-upnp-org:metadata-1-0/DIDL-Lite/"
                   xmlns:dc="http://purl.org/dc/elements/1.1/">
          <item>
            <dc:title>Test</dc:title>
            <res protocolInfo="http-get:*:audio/mpeg:*">http://stream</res>
            <desc id="audioFormat" nameSpace="urn:schemas-denon-com:metadata/"
                  xmlns:aios="urn:schemas-denon-com:metadata/">FLAC</desc>
          </item>
        </DIDL-Lite>
        """

        let metadata = DIDLLiteParser.parse(xml)
        #expect(metadata?.codec == "MP3") // protocolInfo wins
    }

    // MARK: - Wildcard MIME type

    @Test func codecFromProtocolInfoWildcardReturnsNil() {
        #expect(DIDLLiteParser.codecFromProtocolInfo("http-get:*:*:DLNA.ORG_OP=11") == nil)
    }

    // MARK: - XML-escaped input (as returned from SOAP envelope)

    @Test func parsesEscapedXML() {
        let escaped = """
        &lt;DIDL-Lite xmlns:dc=&quot;http://purl.org/dc/elements/1.1/&quot;
                   xmlns:upnp=&quot;urn:schemas-upnp-org:metadata-1-0/upnp/&quot;
                   xmlns=&quot;urn:schemas-upnp-org:metadata-1-0/DIDL-Lite/&quot;&gt;
          &lt;item&gt;
            &lt;upnp:genre&gt;Rock&lt;/upnp:genre&gt;
            &lt;res protocolInfo=&quot;http-get:*:audio/mpeg:*&quot;
                 sampleFrequency=&quot;44100&quot;
                 bitsPerSample=&quot;16&quot;
                 nrAudioChannels=&quot;2&quot;&gt;http://example.com/stream&lt;/res&gt;
          &lt;/item&gt;
        &lt;/DIDL-Lite&gt;
        """

        let metadata = DIDLLiteParser.parse(escaped)
        #expect(metadata != nil)
        #expect(metadata?.sampleRate == 44100)
        #expect(metadata?.bitDepth == 16)
        #expect(metadata?.channels == 2)
        #expect(metadata?.codec == "MP3")
        #expect(metadata?.genre == "Rock")
    }

    // MARK: - Partial data

    @Test func parsesPartialMetadata() {
        let partial = """
        <DIDL-Lite xmlns:dc="http://purl.org/dc/elements/1.1/"
                   xmlns:upnp="urn:schemas-upnp-org:metadata-1-0/upnp/"
                   xmlns="urn:schemas-upnp-org:metadata-1-0/DIDL-Lite/">
          <item>
            <dc:title>Some Song</dc:title>
            <res protocolInfo="http-get:*:audio/mp4:*"
                 sampleFrequency="48000">http://example.com/stream</res>
          </item>
        </DIDL-Lite>
        """

        let metadata = DIDLLiteParser.parse(partial)
        #expect(metadata != nil)
        #expect(metadata?.sampleRate == 48000)
        #expect(metadata?.bitDepth == nil)
        #expect(metadata?.channels == nil)
        #expect(metadata?.codec == "AAC")
        #expect(metadata?.genre == nil)
        #expect(metadata?.trackNumber == nil)
    }

    // MARK: - Empty genre placeholder

    @Test func filtersEmptyQuotePlaceholderGenre() {
        let xml = """
        <DIDL-Lite xmlns="urn:schemas-upnp-org:metadata-1-0/DIDL-Lite/"
                   xmlns:upnp="urn:schemas-upnp-org:metadata-1-0/upnp/">
          <item>
            <upnp:genre>&quot;&quot;</upnp:genre>
            <res sampleFrequency="44100">http://stream</res>
          </item>
        </DIDL-Lite>
        """
        let metadata = DIDLLiteParser.parse(xml)
        #expect(metadata?.genre == nil)
    }

    // MARK: - Empty / nil input

    @Test func returnsNilForNilInput() {
        #expect(DIDLLiteParser.parse(nil) == nil)
    }

    @Test func returnsNilForEmptyString() {
        #expect(DIDLLiteParser.parse("") == nil)
    }

    @Test func returnsNilForInvalidXML() {
        #expect(DIDLLiteParser.parse("not xml at all") == nil)
    }

    @Test func returnsNilForEmptyItem() {
        let empty = """
        <DIDL-Lite xmlns="urn:schemas-upnp-org:metadata-1-0/DIDL-Lite/">
          <item></item>
        </DIDL-Lite>
        """
        #expect(DIDLLiteParser.parse(empty) == nil)
    }

    // MARK: - Codec mapping

    @Test func codecFromProtocolInfoFLAC() {
        #expect(DIDLLiteParser.codecFromProtocolInfo("http-get:*:audio/flac:*") == "FLAC")
    }

    @Test func codecFromProtocolInfoAAC() {
        #expect(DIDLLiteParser.codecFromProtocolInfo("http-get:*:audio/mp4:*") == "AAC")
    }

    @Test func codecFromProtocolInfoMP3() {
        #expect(DIDLLiteParser.codecFromProtocolInfo("http-get:*:audio/mpeg:*") == "MP3")
    }

    @Test func codecFromProtocolInfoWAV() {
        #expect(DIDLLiteParser.codecFromProtocolInfo("http-get:*:audio/x-wav:*") == "WAV")
    }

    @Test func codecFromProtocolInfoUnknownMIME() {
        #expect(DIDLLiteParser.codecFromProtocolInfo("http-get:*:audio/unknown:*") == nil)
    }

    @Test func codecFromProtocolInfoMalformed() {
        #expect(DIDLLiteParser.codecFromProtocolInfo("garbage") == nil)
    }
}

@Suite("TrackMetadata Quality Description Tests")
struct TrackMetadataQualityTests {

    @Test func fullQualityDescription() {
        let meta = TrackMetadata(sampleRate: 96000, bitDepth: 24, codec: "FLAC")
        #expect(meta.qualityDescription == "24-bit / 96 kHz FLAC")
    }

    @Test func cdQuality() {
        let meta = TrackMetadata(sampleRate: 44100, bitDepth: 16, codec: "FLAC")
        #expect(meta.qualityDescription == "16-bit / 44.1 kHz FLAC")
    }

    @Test func bitDepthOnly() {
        let meta = TrackMetadata(bitDepth: 24)
        #expect(meta.qualityDescription == "24-bit")
    }

    @Test func sampleRateOnly() {
        let meta = TrackMetadata(sampleRate: 48000)
        #expect(meta.qualityDescription == "48 kHz")
    }

    @Test func sampleRateWithCodec() {
        let meta = TrackMetadata(sampleRate: 44100, codec: "MP3")
        #expect(meta.qualityDescription == "44.1 kHz MP3")
    }

    @Test func noQualityInfoReturnsNil() {
        let meta = TrackMetadata(genre: "Jazz", trackNumber: 3)
        #expect(meta.qualityDescription == nil)
    }

    @Test func emptyMetadataReturnsNil() {
        let meta = TrackMetadata()
        #expect(meta.qualityDescription == nil)
    }
}
