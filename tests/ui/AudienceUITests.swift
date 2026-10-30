import XCTest

final class AudienceUITests: FlashcardsUITestCase {
    func testAPersonAddedWithGenderAndClosenessShowsBothOnTheList() {
        openTab("Profiles")
        app.buttons["add-profile"].tap()
        app.buttons["New Person"].tap()
        let name = field("profile-name")
        XCTAssertTrue(name.waitForExistence(timeout: 15))
        name.tap()
        name.typeText("Maya")
        app.buttons["profile-gender"].tap()
        XCTAssertTrue(app.buttons["Woman"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.buttons["Man"].exists)
        XCTAssertTrue(app.buttons["Not set"].exists)
        app.buttons["Woman"].tap()
        app.buttons["Dating"].tap()
        app.buttons["profile-save"].tap()

        XCTAssertTrue(app.buttons["profile-row-Maya"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.buttons["profile-row-Maya"].label.contains("Woman · Dating"))
    }

    func testTheRelationshipControlOnTheProfileScreenMovesAPersonInOneTap() {
        addPerson("Maya")
        app.buttons["profile-row-Maya"].tap()
        let control = app.segmentedControls["relationship-control"]
        XCTAssertTrue(control.waitForExistence(timeout: 15))
        XCTAssertTrue(control.buttons["Friend"].isSelected)

        control.buttons["Dating"].tap()

        XCTAssertTrue(control.buttons["Dating"].isSelected)
    }

    func testSettingsOffersIAmWithNotSetManAndWoman() {
        openTab("Settings")
        let picker = app.buttons["i-am"]
        XCTAssertTrue(picker.waitForExistence(timeout: 15))

        picker.tap()

        XCTAssertTrue(app.buttons["Not set"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.buttons["Man"].exists)
        XCTAssertTrue(app.buttons["Woman"].exists)
        app.buttons["Man"].tap()
        XCTAssertTrue(app.buttons["i-am"].label.contains("Man"))
    }

    func testACouplesDareIsSavedButStaysOutOfAnUntaggedPersonsStack() {
        addPerson("Maya")
        openTab("Library")
        app.buttons["new-card"].tap()
        let prompt = field("card-prompt")
        XCTAssertTrue(prompt.waitForExistence(timeout: 15))
        app.buttons["Dare"].tap()
        prompt.tap()
        prompt.typeText("Hold hands for a minute")
        app.buttons["card-audience"].tap()
        XCTAssertTrue(app.buttons["Couples"].waitForExistence(timeout: 15))
        app.buttons["Couples"].tap()
        app.buttons["card-save"].tap()
        XCTAssertTrue(app.buttons["my-card-Hold hands for a minute"].waitForExistence(timeout: 15))

        openTab("Cards")
        XCTAssertTrue(app.staticTexts["progress"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts["progress"].label.hasPrefix("0 of 6 asked"))
    }
}
