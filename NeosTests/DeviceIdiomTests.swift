import XCTest
@testable import Neos
#if os(iOS)
import UIKit
#endif

final class DeviceIdiomTests: XCTestCase {
    func testASentenceNamesTheDeviceTheAppRunsOn() {
        #if os(macOS)
        XCTAssertEqual(DeviceIdiom.name, "Mac")
        XCTAssertFalse(DeviceIdiom.isPad)
        #else
        let isPad = UIDevice.current.userInterfaceIdiom == .pad
        XCTAssertEqual(DeviceIdiom.name, isPad ? "iPad" : "iPhone")
        XCTAssertEqual(DeviceIdiom.isPad, isPad)
        #endif
    }
}
