import XCTest

/// The Add Station form must survive the image picker taking key window.
final class DemoAddStationTests: DemoTestCase {

    private var browse: BrowseScreen { BrowseScreen(app: app) }

    /// The picker button stands for the form: its Text labels are not exposed to XCUI.
    private var form: XCUIElement {
        app.buttons.matching(NSPredicate(format: "label CONTAINS 'Choose Image'")).firstMatch
    }

    private func openForm() {
        if form.exists { return }
        let stations = SidebarScreen(app: app).sourceButton(sid: 1028)
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

        // The open panel comes down as a sheet on the form's sheet; dismissing it must leave the form standing.
        let panel = app.sheets["open-panel"]
        waitForElement(panel)
        app.typeKey(.escape, modifierFlags: [])
        waitForElementToDisappear(panel)

        XCTAssertTrue(form.exists, "The form must not be dismissed by the file panel")
    }
}
