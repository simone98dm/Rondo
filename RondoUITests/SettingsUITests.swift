import XCTest

final class SettingsUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    private func launch(pane: String = "general") -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--open-settings=\(pane)"]
        app.launch()
        return app
    }

    func testEveryPaneOpens() {
        let app = launch()
        let window = app.windows["settings"]
        XCTAssertTrue(window.waitForExistence(timeout: 10))
        for title in ["General", "Menu Bar", "Window Manager", "Window Switcher", "Disk Clean", "Power & Keyboard", "About & Help"] {
            let row = window.outlines.staticTexts[title]
            XCTAssertTrue(row.exists, "missing sidebar entry \(title)")
            row.click()
            XCTAssertEqual(window.title, title, "pane \(title) didn't open")
        }
    }

    func testSearchFiltersSidebar() {
        let app = launch()
        let window = app.windows["settings"]
        XCTAssertTrue(window.waitForExistence(timeout: 10))
        let search = window.searchFields.firstMatch
        search.click()
        search.typeText("thumbnails")
        XCTAssertTrue(window.outlines.staticTexts["Window Switcher"].waitForExistence(timeout: 3))
        XCTAssertFalse(window.outlines.staticTexts["Menu Bar"].exists)
    }

    func testMenuBarToggleChangesState() {
        let app = launch(pane: "menuBar")
        let window = app.windows["settings"]
        XCTAssertTrue(window.waitForExistence(timeout: 10))
        let cpu = window.checkBoxes["CPU usage"]
        XCTAssertTrue(cpu.waitForExistence(timeout: 3))
        let before = cpu.value as? Int
        cpu.click()
        XCTAssertNotEqual(cpu.value as? Int, before)
    }

    func testCommandCommaOpensRealSettingsWindow() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--open-about"]
        app.launch()
        XCTAssertTrue(app.windows["about"].waitForExistence(timeout: 10))
        app.typeKey(",", modifierFlags: .command)
        let settings = app.windows["settings"]
        XCTAssertTrue(settings.waitForExistence(timeout: 5))
        XCTAssertTrue(settings.outlines.staticTexts["General"].exists)
        // the empty SwiftUI Settings scene must not open alongside it
        XCTAssertEqual(app.windows.matching(NSPredicate(format: "identifier != 'settings' AND identifier != 'about'")).count, 0,
                       app.debugDescription)
    }
}
