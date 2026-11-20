import XCTest
@testable import Neos

final class ServiceBrandingTests: XCTestCase {
    func testAKnownServiceHasALogo() {
        XCTAssertEqual(ServiceBranding.iconAssetName(for: "Deezer"), "service-icon-deezer")
        XCTAssertEqual(ServiceBranding.iconAssetName(for: "TuneIn"), "service-icon-tunein")
    }

    func testALocalSourceHasNoLogoButASymbolOfItsOwn() {
        XCTAssertNil(ServiceBranding.iconAssetName(for: "AUX Input"))
        XCTAssertEqual(ServiceBranding.symbolName(for: "AUX Input"), DS.Icons.cableConnector)
        XCTAssertEqual(ServiceBranding.symbolName(for: "Local Music"), DS.Icons.musicNoteHouse)
    }

    func testAnUnknownSourceFallsBackToOneSymbol() {
        XCTAssertEqual(ServiceBranding.symbolName(for: "Something New"), DS.Icons.playlists)
    }

    func testOnlyServicesAndServersShowTheirMarkInHeaders() {
        XCTAssertTrue(ServiceBranding.hasBrandIdentity(for: "TIDAL"))
        XCTAssertTrue(ServiceBranding.hasBrandIdentity(for: "Local Music"))
        XCTAssertFalse(ServiceBranding.hasBrandIdentity(for: "AUX Input"))
    }
}
