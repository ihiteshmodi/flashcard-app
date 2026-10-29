import XCTest

/// Shared helpers for the simulator flows. Every flow starts from an empty in-memory database
/// with made-up demo decks, and cards in deck order so the first card is known.
class FlashcardsUITestCase: XCTestCase {
    var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-UITestInMemory", "-UITestDemoData"]
        app.launch()
    }

    /// The tab bar is not always exposed as a `tabBar` element, so tabs are found by their button label.
    func openTab(_ name: String) {
        let tab = app.buttons[name].firstMatch
        XCTAssertTrue(tab.waitForExistence(timeout: 10))
        tab.tap()
    }

    /// Text fields and multi-line text views both match, so tests do not depend on the field's axis.
    func field(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    func addPerson(_ name: String) {
        openTab("Profiles")
        app.buttons["add-profile"].tap()
        app.buttons["New Person"].tap()
        let nameField = field("profile-name")
        XCTAssertTrue(nameField.waitForExistence(timeout: 15))
        nameField.tap()
        nameField.typeText(name)
        app.buttons["profile-save"].tap()
        XCTAssertTrue(app.buttons["profile-row-\(name)"].waitForExistence(timeout: 15))
    }
}
