import XCTest
import SwiftUI
@testable import Neos

@MainActor
final class TypographyColorTests: XCTestCase {
    func testARoleShowsItsOwnColour() throws {
        XCTAssertEqual(
            try pixel(of: Rectangle().typography(.secondary)),
            try pixel(of: Rectangle().foregroundStyle(DS.Colors.textSecondary))
        )
        XCTAssertEqual(
            try pixel(of: Rectangle().typography(.footnote)),
            try pixel(of: Rectangle().foregroundStyle(DS.Colors.textTertiary))
        )
    }

    func testAGivenColourReplacesTheRolesColour() throws {
        XCTAssertEqual(
            try pixel(of: Rectangle().typography(.secondary, color: DS.Colors.destructive)),
            try pixel(of: Rectangle().foregroundStyle(DS.Colors.destructive))
        )
    }

    func testAPrimaryRoleFollowsTheStyleAroundIt() throws {
        XCTAssertEqual(
            try pixel(of: VStack { Rectangle().typography(.bodyPrimary) }.foregroundStyle(DS.Colors.accent)),
            try pixel(of: Rectangle().foregroundStyle(DS.Colors.accent))
        )
    }

    private func pixel(of view: some View) throws -> [UInt8] {
        let renderer = ImageRenderer(content: view.frame(width: 4, height: 4))
        renderer.scale = 1
        let image = try XCTUnwrap(renderer.cgImage)
        var bytes = [UInt8](repeating: 0, count: 4)
        let context = try XCTUnwrap(CGContext(
            data: &bytes, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.draw(image, in: CGRect(x: 0, y: 0, width: 1, height: 1))
        return bytes
    }
}
