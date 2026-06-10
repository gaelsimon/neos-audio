import XCTest

/// Tests for Settings and Amp Settings views in demo mode.
/// Covers account section, volume limit, about, and amp player listing.
final class DemoSettingsTests: DemoTestCase {

    private var settings: SettingsScreen { SettingsScreen(app: app) }
    private var ampSettings: AmpSettingsScreen { AmpSettingsScreen(app: app) }
    private var topBar: TopBarScreen { TopBarScreen(app: app) }
    private var sidebar: SidebarScreen { SidebarScreen(app: app) }

    override func setUp() {
        super.setUp()
        resetToHome()
    }

    private func navigateToSettings() {
        waitForElement(topBar.profileButton)
        topBar.profileButton.click()
        waitForElement(settings.view)
    }

    private func navigateToAmpSettings() {
        waitForElement(sidebar.ampCard)
        sidebar.ampCard.click()
        waitForElement(ampSettings.view)
    }

    // MARK: - Account Settings (Signed In State)

    func testSettingsViewExists() {
        navigateToSettings()
        XCTAssertTrue(settings.view.exists)
    }

    func testSignedInUserDisplayed() {
        navigateToSettings()
        waitForElement(settings.signedInUser)
        XCTAssertTrue(settings.signedInUser.exists, "Signed-in user label should exist in demo mode")
    }

    func testSignOutButtonExistsWhenSignedIn() {
        navigateToSettings()
        waitForElement(settings.signOutButton)
        XCTAssertTrue(settings.signOutButton.exists, "Sign out button should exist when signed in")
    }

    func testSignInFormNotVisibleWhenSignedIn() {
        navigateToSettings()
        waitForElement(settings.signedInUser)
        XCTAssertFalse(settings.emailField.exists, "Email field should not exist when signed in")
        XCTAssertFalse(settings.passwordField.exists, "Password field should not exist when signed in")
    }

    // MARK: - Volume Limit

    func testVolumeLimitToggleExists() {
        navigateToSettings()
        let toggle = app.descendants(matching: .any)[AccessibilityID.Settings.volumeLimitToggle]
        waitForElement(toggle)
        XCTAssertTrue(toggle.exists, "Volume limit toggle should exist")
    }

    // MARK: - Cache

    func testCacheSizeLabelExists() {
        navigateToSettings()
        let label = app.descendants(matching: .any)[AccessibilityID.Settings.cacheSizeLabel]
        waitForElement(label)
        XCTAssertTrue(label.exists, "Cache size label should exist")
    }

    func testClearCacheButtonExists() {
        navigateToSettings()
        let button = app.descendants(matching: .any)[AccessibilityID.Settings.clearCacheButton]
        waitForElement(button)
        XCTAssertTrue(button.exists, "Clear cache button should exist")
    }

    // MARK: - About

    func testAboutVersionExists() {
        navigateToSettings()
        let version = app.descendants(matching: .any)[AccessibilityID.Settings.aboutVersion]
        waitForElement(version)
        XCTAssertTrue(version.exists, "About version should exist")
    }

    func testAboutBuildExists() {
        navigateToSettings()
        let build = app.descendants(matching: .any)[AccessibilityID.Settings.aboutBuild]
        waitForElement(build)
        XCTAssertTrue(build.exists, "About build should exist")
    }

    func testAboutCopyrightExists() {
        navigateToSettings()
        let copyright = app.descendants(matching: .any)[AccessibilityID.Settings.aboutCopyright]
        waitForElement(copyright)
        XCTAssertTrue(copyright.exists, "About copyright should exist")
    }

    // MARK: - Diagnostics

    func testCopyDiagnosticsButtonExists() {
        navigateToSettings()
        let button = app.descendants(matching: .any)[AccessibilityID.Settings.copyDiagnosticsButton]
        waitForElement(button)
        XCTAssertTrue(button.exists, "Copy diagnostics button should exist")
    }

    // MARK: - Amp Settings

    func testAmpSettingsViewExists() {
        navigateToAmpSettings()
        XCTAssertTrue(ampSettings.view.exists)
    }

    func testAmpSettingsShowsAllPlayerRows() {
        navigateToAmpSettings()
        // Demo has 3 players: AVR main zone, AVR Zone 2, Home 150 Pair
        let avrMain = ampSettings.playerRow(1_845_498_270)
        let avrZone2 = ampSettings.playerRow(1_845_498_271)
        let home150 = ampSettings.playerRow(927_361_084)

        waitForElement(avrMain)
        XCTAssertTrue(avrMain.exists, "AVR main zone row should exist")
        XCTAssertTrue(avrZone2.exists, "AVR Zone 2 row should exist")
        XCTAssertTrue(home150.exists, "Home 150 Pair row should exist")
    }

    func testAmpSettingsHome150IsSelected() {
        navigateToAmpSettings()
        // The standalone speaker (Home 150) should be the selected player,
        // not an AVR zone; verifies the preferredPlayer selection logic.
        let home150Button = app.buttons.matching(identifier: AccessibilityID.AmpSettings.playerRow(927_361_084))
            .matching(NSPredicate(format: "label == %@", "Home 150 Pair")).firstMatch
        let avrMainButton = app.buttons.matching(identifier: AccessibilityID.AmpSettings.playerRow(1_845_498_270))
            .matching(NSPredicate(format: "label == %@", "Denon AVR-X2800H")).firstMatch
        waitForElement(home150Button)

        XCTAssertEqual(
            home150Button.value as? String, "selected",
            "Home 150 should be the selected player"
        )
        XCTAssertEqual(
            avrMainButton.value as? String, "unselected",
            "AVR main zone should not be selected"
        )
    }

    func testAmpSettingsShowsGroupCreation() {
        navigateToAmpSettings()
        // With 3 players, group creation form should be available (requires ≥2)
        let leaderPicker = ampSettings.leaderPicker
        waitForElement(leaderPicker)
        XCTAssertTrue(leaderPicker.exists, "Group leader picker should exist with multiple players")
    }

    // MARK: - Player Selection

    // Demo PIDs (must match DemoDataProvider in the app target)
    private let avrMainPID = 1_845_498_270
    private let avrZone2PID = 1_845_498_271
    private let home150PID = 927_361_084

    func testSelectAVRMainZoneSwitchesSelectedPlayer() {
        navigateToAmpSettings()
        let avrButton = ampSettings.playerButton(avrMainPID, label: "Denon AVR-X2800H")
        let home150Button = ampSettings.playerButton(home150PID, label: "Home 150 Pair")
        waitForElement(avrButton)

        // Precondition: Home 150 is selected
        XCTAssertEqual(home150Button.value as? String, "selected")
        XCTAssertEqual(avrButton.value as? String, "unselected")

        // Act: click the AVR main zone row
        avrButton.click()

        // Assert: AVR becomes selected, Home 150 deselected
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value == %@", "selected"),
            object: avrButton
        )
        wait(for: [expectation], timeout: 3)
        XCTAssertEqual(avrButton.value as? String, "selected", "AVR main zone should now be selected")
        XCTAssertEqual(home150Button.value as? String, "unselected", "Home 150 should now be unselected")
    }

    func testSelectAVRZone2SwitchesSelectedPlayer() {
        navigateToAmpSettings()
        let zone2Button = ampSettings.playerButton(avrZone2PID, label: "Denon AVR-X2800H - Zone 2")
        waitForElement(zone2Button)

        zone2Button.click()

        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value == %@", "selected"),
            object: zone2Button
        )
        wait(for: [expectation], timeout: 3)
        XCTAssertEqual(zone2Button.value as? String, "selected", "Zone 2 should now be selected")
    }

    func testReselectHome150AfterSwitching() {
        navigateToAmpSettings()
        let avrButton = ampSettings.playerButton(avrMainPID, label: "Denon AVR-X2800H")
        let home150Button = ampSettings.playerButton(home150PID, label: "Home 150 Pair")
        waitForElement(avrButton)

        // Switch to AVR, then back to Home 150
        avrButton.click()
        let switched = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value == %@", "selected"),
            object: avrButton
        )
        wait(for: [switched], timeout: 3)

        home150Button.click()
        let restored = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value == %@", "selected"),
            object: home150Button
        )
        wait(for: [restored], timeout: 3)
        XCTAssertEqual(home150Button.value as? String, "selected", "Home 150 should be selected again")
        XCTAssertEqual(avrButton.value as? String, "unselected")
    }

    // MARK: - Group Creation Form

    func testCreateGroupButtonDisabledWithNoMembers() {
        navigateToAmpSettings()
        waitForElement(ampSettings.createGroupButton)
        XCTAssertFalse(
            ampSettings.createGroupButton.isEnabled,
            "Create group button should be disabled when no members are toggled"
        )
    }

    func testAllMemberTogglesExist() {
        navigateToAmpSettings()
        waitForElement(ampSettings.leaderPicker)
        // Before leader is explicitly chosen, all player toggles are shown
        let avrToggle = ampSettings.memberToggle(avrMainPID)
        let zone2Toggle = ampSettings.memberToggle(avrZone2PID)
        let home150Toggle = ampSettings.memberToggle(home150PID)
        XCTAssertTrue(avrToggle.exists, "AVR main zone should have a member toggle")
        XCTAssertTrue(zone2Toggle.exists, "Zone 2 should have a member toggle")
        XCTAssertTrue(home150Toggle.exists, "Home 150 should have a member toggle")
    }

    func testMemberToggleIsClickable() {
        navigateToAmpSettings()
        let memberToggle = ampSettings.memberToggle(home150PID)
        waitForElement(memberToggle)

        // Toggle on and verify value changes
        memberToggle.click()
        let toggled = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value == 1"),
            object: memberToggle
        )
        wait(for: [toggled], timeout: 3)
    }
}
