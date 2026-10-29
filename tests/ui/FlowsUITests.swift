import XCTest

final class FlowsUITests: FlashcardsUITestCase {
    func testAddingAPersonShowsThemInTheProfileList() {
        addPerson("Maya")

        XCTAssertTrue(app.buttons["profile-row-Maya"].exists)
    }

    func testSwipingACardRightSavesAnOptionalAnswerThatShowsInTheProfileHistory() {
        addPerson("Maya")
        openTab("Cards")

        XCTAssertTrue(app.otherElements["card-demo-deep-001"].waitForExistence(timeout: 15)
            || app.staticTexts["What is a belief you changed your mind about?"].waitForExistence(timeout: 15))
        app.buttons["asked-button"].tap()
        let note = field("answer-note")
        XCTAssertTrue(note.waitForExistence(timeout: 15))
        note.tap()
        note.typeText("Used to hustle every day")
        app.buttons["save-answer"].tap()

        XCTAssertTrue(app.staticTexts["progress"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts["progress"].label.hasPrefix("1 of 6 asked"))

        openTab("Profiles")
        app.buttons["profile-row-Maya"].tap()
        XCTAssertTrue(app.staticTexts["Used to hustle every day"].waitForExistence(timeout: 15))
    }

    func testNotNowStillCountsTheCardAsAskedAndUndoBringsItBack() {
        addPerson("Maya")
        openTab("Cards")

        app.buttons["asked-button"].tap()
        XCTAssertTrue(app.buttons["not-now"].waitForExistence(timeout: 15))
        app.buttons["not-now"].tap()
        XCTAssertTrue(app.staticTexts["progress"].label.hasPrefix("1 of 6 asked"))

        app.buttons["undo-button"].tap()
        XCTAssertTrue(app.staticTexts["progress"].label.hasPrefix("0 of 6 asked"))
    }

    func testAGroupKeepsItsOwnAnswersLabelledWithWhoAnswered() {
        addPerson("Maya")
        addPerson("Sam")
        app.buttons["add-profile"].tap()
        app.buttons["New Group"].tap()
        let name = field("group-name")
        XCTAssertTrue(name.waitForExistence(timeout: 15))
        name.tap()
        name.typeText("Friends")
        app.buttons["member-Maya"].tap()
        app.buttons["member-Sam"].tap()
        app.buttons["group-create"].tap()
        XCTAssertTrue(app.buttons["profile-row-Friends"].waitForExistence(timeout: 15))

        openTab("Cards")
        XCTAssertTrue(app.buttons["profile-chip"].label.contains("Friends"))
        app.buttons["asked-button"].tap()
        XCTAssertTrue(app.buttons["answerer-Sam"].waitForExistence(timeout: 15))
        app.buttons["answerer-Sam"].tap()
        let note = field("answer-note")
        note.tap()
        note.typeText("Calls park security")
        app.buttons["save-answer"].tap()

        openTab("Profiles")
        app.buttons["profile-row-Friends"].tap()
        XCTAssertTrue(app.staticTexts["Sam: Calls park security"].waitForExistence(timeout: 15))
    }

    func testAnswersFromAGroupNeverShowInAMembersOwnHistory() {
        addPerson("Maya")
        app.buttons["add-profile"].tap()
        app.buttons["New Group"].tap()
        let name = field("group-name")
        XCTAssertTrue(name.waitForExistence(timeout: 15))
        name.tap()
        name.typeText("Duo")
        app.buttons["member-Maya"].tap()
        app.buttons["group-create"].tap()

        openTab("Cards")
        app.buttons["asked-button"].tap()
        let note = field("answer-note")
        XCTAssertTrue(note.waitForExistence(timeout: 15))
        note.tap()
        note.typeText("Group only")
        app.buttons["save-answer"].tap()

        openTab("Profiles")
        app.buttons["profile-row-Maya"].tap()
        XCTAssertTrue(app.staticTexts["Nothing asked yet. Swipe a card right on the Cards tab."].waitForExistence(timeout: 15))
        XCTAssertFalse(app.staticTexts["Group only"].exists)
    }

    func testOwnCardAppearsInTheStackAfterItIsCreated() {
        addPerson("Maya")
        openTab("Library")
        app.buttons["new-card"].tap()
        let prompt = field("card-prompt")
        XCTAssertTrue(prompt.waitForExistence(timeout: 15))
        prompt.tap()
        prompt.typeText("What is your comfort movie?")
        app.buttons["card-save"].tap()
        XCTAssertTrue(app.buttons["my-card-What is your comfort movie?"].waitForExistence(timeout: 15))

        openTab("Cards")
        XCTAssertTrue(app.staticTexts["progress"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts["progress"].label.hasPrefix("0 of 7 asked"))
    }

    func testTheSettingsScreenOffersExportAndImport() {
        openTab("Settings")

        XCTAssertTrue(app.buttons["export-files"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.buttons["export-share"].exists)
        XCTAssertTrue(app.buttons["import-database"].exists)
    }
}
