import XCTest

/// Breadcrumb path in demo mode: absent at a source root, the parents of the current level above it.
final class DemoBreadcrumbTests: DemoTestCase {

    private var sidebar: SidebarScreen { SidebarScreen(app: app) }
    private var browse: BrowseScreen { BrowseScreen(app: app) }

    override func setUp() {
        super.setUp()
        resetToHome()
    }

    // Rows carry no identifier of their own, so they are reached through their icon.
    private func clickFirstContainerRow() {
        let folder = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == 'folder'")).firstMatch
        waitForElement(folder)
        folder.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).click()
    }

    private func clickRow(labelled label: String) {
        let row = app.buttons.matching(NSPredicate(format: "label == %@", label)).firstMatch
        waitForElement(row)
        row.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).click()
    }

    private func openDeezerRoot() {
        waitForElement(sidebar.sourceButton(sid: 2))
        sidebar.sourceButton(sid: 2).click()
        waitForElement(browse.view)
    }

    private func openFirstCategory() {
        openDeezerRoot()
        clickFirstContainerRow()
        waitForElement(browse.breadcrumb)
    }

    func testBreadcrumbHiddenAtSourceRoot() {
        openDeezerRoot()
        waitForElementToDisappear(browse.breadcrumb)
        XCTAssertFalse(browse.breadcrumb.exists, "A source root should show no breadcrumb")
    }

    func testBreadcrumbShowsPathInsideContainer() {
        openFirstCategory()

        XCTAssertEqual(browse.breadcrumbItem(0).label, "Deezer", "First crumb should name the source")
        XCTAssertFalse(browse.breadcrumbItem(1).exists, "The current level is the page title, not a crumb")
    }

    func testBreadcrumbRootCrumbReturnsToSourceRoot() {
        openFirstCategory()

        browse.breadcrumbItem(0).click()

        waitForElementToDisappear(browse.breadcrumb)
        XCTAssertTrue(browse.view.exists, "Source root listing should be back")
    }

    func testBreadcrumbGrowsWithDepth() {
        openFirstCategory()

        clickRow(labelled: "A Night at the Opera, Queen")

        waitForElement(browse.breadcrumbItem(1))
        XCTAssertFalse(browse.breadcrumbItem(2).exists, "The path stops at the parent of the current level")
    }
}
