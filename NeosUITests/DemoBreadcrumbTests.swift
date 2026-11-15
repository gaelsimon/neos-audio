import XCTest

/// Breadcrumb path in demo mode: absent at a source root, the parents of the current level above it.
final class DemoBreadcrumbTests: DemoTestCase {

    private var sidebar: SidebarScreen { SidebarScreen(app: app) }
    private var browse: BrowseScreen { BrowseScreen(app: app) }

    // Rows and tiles carry no identifier of their own: each is one button labelled from its texts.
    private func clickRow(labelled label: String) {
        let row = app.buttons.matching(NSPredicate(format: "label == %@", label)).firstMatch
        waitForElement(row)
        row.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).click()
    }

    /// From wherever the previous test stopped: a click on a source's row always lands on its first page.
    private func openDeezerRoot() {
        waitForElement(sidebar.sourceButton(sid: 2))
        sidebar.sourceButton(sid: 2).click()
        waitForElement(browse.view)
    }

    private func openFirstCategory() {
        openDeezerRoot()
        clickRow(labelled: "Albums")
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

    func testClickingTheSelectedSourceReturnsToItsRoot() {
        openFirstCategory()

        sidebar.sourceButton(sid: 2).click()

        waitForElementToDisappear(browse.breadcrumb)
        XCTAssertTrue(browse.view.exists, "Source root listing should be back")
    }

    func testBreadcrumbGrowsWithDepth() {
        openFirstCategory()

        clickRow(labelled: "Midnight Opera, The Velvet Hours")

        waitForElement(browse.breadcrumbItem(1))
        XCTAssertFalse(browse.breadcrumbItem(2).exists, "The path stops at the parent of the current level")
    }
}
