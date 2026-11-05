import XCTest

final class PopoverUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    private func launch(_ extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--open-popover-window"] + extra
        app.launch()
        return app
    }

    func testAllTabsAreReachable() {
        let app = launch()
        let window = app.windows["Rondo"]
        XCTAssertTrue(window.waitForExistence(timeout: 10))
        for title in ["System", "Disk", "Windows", "Switcher", "Convert"] {
            let tab = window.buttons[title]
            XCTAssertTrue(tab.exists, "missing tab \(title)")
            tab.click()
        }
    }

    func testCommandNumberSwitchesTabs() {
        let app = launch()
        let window = app.windows["Rondo"]
        XCTAssertTrue(window.waitForExistence(timeout: 10))
        window.typeKey("3", modifierFlags: .command)
        XCTAssertTrue(window.staticTexts["Accessibility Required"].waitForExistence(timeout: 3))
        window.typeKey("2", modifierFlags: .command)
        // Disk tab: an analysis (Rescan) or, without Mole, the setup prompt
        XCTAssertTrue(window.buttons["Rescan"].waitForExistence(timeout: 30) || window.buttons["Set Up Mole…"].exists)
    }

    func testGearOpensSettingsWindow() {
        let app = launch()
        let window = app.windows["Rondo"]
        XCTAssertTrue(window.waitForExistence(timeout: 10))
        window.buttons["Settings"].click()
        XCTAssertTrue(app.windows["settings"].waitForExistence(timeout: 5))
    }

    func testConverterToggleSwitchesState() {
        let app = launch()
        let window = app.windows["Rondo"]
        XCTAssertTrue(window.waitForExistence(timeout: 10))
        window.buttons["Convert"].click()
        let toggle = window.descendants(matching: .any)["Enable File Converter"].firstMatch
        XCTAssertTrue(toggle.waitForExistence(timeout: 3), app.debugDescription)
        XCTAssertEqual("\(toggle.value ?? "")", "1") // on by default
        toggle.click()
        XCTAssertTrue(window.buttons["Turn On"].waitForExistence(timeout: 3))
        window.buttons["Turn On"].click()
        XCTAssertEqual("\(toggle.value ?? "")", "1")
    }

    func testTabStateSurvivesSwitching() {
        let app = launch()
        let window = app.windows["Rondo"]
        XCTAssertTrue(window.waitForExistence(timeout: 10))
        window.typeKey("2", modifierFlags: .command)
        // Mole may be missing on the test machine: then the tab offers setup instead of an analysis
        let ready = window.buttons["Rescan"].waitForExistence(timeout: 30) || window.buttons["Set Up Mole…"].exists
        XCTAssertTrue(ready)
        window.typeKey("1", modifierFlags: .command)
        window.typeKey("2", modifierFlags: .command)
        // the Disk tab is kept alive: no fresh analysis or empty state when coming back
        XCTAssertFalse(window.buttons["Analyze Disk"].exists)
        XCTAssertTrue(window.buttons["Rescan"].exists || window.buttons["Set Up Mole…"].exists)
    }
}
