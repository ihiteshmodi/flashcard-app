import XCTest

final class AddPersonUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func testAddingAPersonShowsThemInTheProfileList() {
        let app = XCUIApplication()
        app.launchArguments = ["-UITestInMemory"]
        app.launch()

        app.buttons["add-person"].tap()
        let field = app.alerts.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("Maya")
        app.alerts.buttons["Add"].tap()

        XCTAssertTrue(app.staticTexts["profile-row-Maya"].waitForExistence(timeout: 5))
    }
}
