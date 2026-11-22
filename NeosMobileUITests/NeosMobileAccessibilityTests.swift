import XCTest

/// Apple's accessibility audit on the pages of the iPhone and iPad app, for what the app decides itself: the size of
/// what a finger has to hit, and a name for everything VoiceOver stops on.
final class NeosMobileAccessibilityTests: MobileDemoTestCase {
    /// Left out: contrast, which the audit also reads through the bars; clipped text, since long titles are cut on
    /// purpose; and text sizes, which stop at xxxLarge while rows keep a fixed height.
    private let audited: XCUIAccessibilityAuditType = [.hitRegion, .sufficientElementDescription]

    private func assertThePagePassesTheAudit(file: StaticString = #filePath, line: UInt = #line) {
        var found: [String] = []
        do {
            try app.performAccessibilityAudit(for: audited) { [self] issue in
                guard let element = issue.element, let seen = try? element.snapshot() else { return true }
                if isAccepted(seen) { return true }
                found.append("\(issue.compactDescription): \(seen.identifier) \"\(seen.label)\" \(Int(seen.frame.width))x\(Int(seen.frame.height))")
                return true
            }
        } catch {
            XCTFail("The audit did not finish: \(error)", file: file, line: line)
        }
        XCTAssertTrue(found.isEmpty, found.joined(separator: "\n"), file: file, line: line)
    }

    /// What the audit reports and the app keeps, each for its reason.
    private func isAccepted(_ element: XCUIElementSnapshot) -> Bool {
        // The system's own button in its search field.
        if element.label == "Clear text" { return true }
        // An e-mail address does not read as a sentence.
        if element.identifier == AccessibilityID.Settings.signedInUser { return true }
        // The iPad's player bar and the path above a page keep the Mac's text links, sized as text.
        if isPad, element.identifier.hasPrefix("browse.breadcrumb") { return true }
        if isPad, self.element(AccessibilityID.Player.bar).frame.contains(element.frame) { return true }
        return false
    }

    func testHomePassesTheAudit() {
        assertThePagePassesTheAudit()
    }

    func testTheLibraryPassesTheAudit() {
        tab("Library").tap()

        assertThePagePassesTheAudit()
    }

    func testAnAlbumPassesTheAudit() {
        openLibraryPage("Deezer")
        open("Albums", "Midnight Opera,")

        assertThePagePassesTheAudit()
    }

    func testAGridPassesTheAudit() {
        openLibraryPage("Deezer")
        open("Artists", "The Velvet Hours")

        assertThePagePassesTheAudit()
    }

    func testTheQueuePassesTheAudit() {
        openLibraryPage("Queue")

        assertThePagePassesTheAudit()
    }

    func testSearchResultsPassTheAudit() {
        search("mi")

        assertThePagePassesTheAudit()
    }

    func testThePlayerPassesTheAudit() throws {
        // On iPad the audit of the full-screen player never returns.
        try XCTSkipIf(isPad, "The audit does not finish on the iPad's player")
        openPlayer()

        assertThePagePassesTheAudit()
    }

    func testTheSpeakersPassTheAudit() {
        app.buttons["Speakers"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Speakers"].waitForExistence(timeout: 5))

        assertThePagePassesTheAudit()
    }

    func testSettingsPassTheAudit() {
        app.buttons["Settings"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))

        assertThePagePassesTheAudit()
    }
}
