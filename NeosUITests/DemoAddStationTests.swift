import XCTest

/// The Add Station form must survive the image picker taking key window.
final class DemoAddStationTests: DemoTestCase {

    private var browse: BrowseScreen { BrowseScreen(app: app) }

    override func setUp() {
        super.setUp()
        resetToHome()
    }

    /// The picker button stands for the form: its Text labels are not exposed to XCUI.
    private var form: XCUIElement {
        app.buttons.matching(NSPredicate(format: "label CONTAINS 'Choose Image'")).firstMatch
    }

    private func openForm() {
        let stations = app.buttons.matching(NSPredicate(format: "label == 'Favorites'")).firstMatch
        waitForElement(stations)
        stations.click()
        waitForElement(browse.addStationButton)
        browse.addStationButton.click()
        waitForElement(form)
    }

    func testFormOpens() {
        openForm()
        XCTAssertTrue(form.exists, "Add Station should present its form")
    }

    func testFormSurvivesTheImagePicker() {
        openForm()

        form.click()

        // The open panel is a separate key window; dismissing it must leave the form standing.
        let panel = app.dialogs.firstMatch
        waitForElement(panel)
        app.typeKey(.escape, modifierFlags: [])
        waitForElementToDisappear(panel)

        XCTAssertTrue(form.exists, "The form must not be dismissed by the file panel")
    }
}
