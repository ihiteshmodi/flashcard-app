import XCTest

final class GameUITests: FlashcardsUITestCase {
    private func snapshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func passedTo(_ name: String, file: StaticString = #filePath, line: UInt = #line) {
        let label = app.staticTexts["pass-to"]
        XCTAssertTrue(label.waitForExistence(timeout: 15), file: file, line: line)
        XCTAssertEqual(label.label, name, file: file, line: line)
    }

    private func lockInOption(_ optionIndex: Int, as name: String, capturePrefix: String? = nil) {
        passedTo(name)
        if let capturePrefix { snapshot("\(capturePrefix)-pass") }
        app.buttons["ready"].tap()
        XCTAssertFalse(app.buttons["ready"].exists)
        let card = app.buttons["option-card-\(optionIndex)"]
        XCTAssertTrue(card.waitForExistence(timeout: 15))
        XCTAssertFalse(app.buttons["submit-cards"].isEnabled, "nothing is pre-selected from earlier players")
        card.tap()
        if let capturePrefix { snapshot("\(capturePrefix)-choose") }
        app.buttons["submit-cards"].tap()
    }

    func testTwoExistingPeopleCanReuseTheSameAnswerSeeEveryonesSelectionAndKeepItInHistory() {
        addPerson("Maya")
        addPerson("Sam")
        openTab("Game")

        app.buttons["game-person-Maya"].tap()
        app.buttons["game-person-Sam"].tap()
        snapshot("1-setup")
        app.buttons["start-game"].tap()

        lockInOption(0, as: "Maya", capturePrefix: "2-maya")
        lockInOption(0, as: "Sam")

        XCTAssertTrue(app.staticTexts["reveal-header"].waitForExistence(timeout: 15))
        snapshot("3-reveal")
        let mayaReveal = app.descendants(matching: .any)["reveal-Maya"].firstMatch
        let samReveal = app.descendants(matching: .any)["reveal-Sam"].firstMatch
        XCTAssertTrue(mayaReveal.exists)
        XCTAssertTrue(samReveal.exists)
        XCTAssertTrue(mayaReveal.label.contains("Great Aunt Sharon"), mayaReveal.label)
        XCTAssertTrue(samReveal.label.contains("Great Aunt Sharon"), samReveal.label)

        app.buttons["next-round"].tap()
        passedTo("Maya")

        openTab("Profiles")
        app.buttons["profile-row-Maya"].tap()
        XCTAssertTrue(app.staticTexts["A big wet kiss from Great Aunt Sharon."].waitForExistence(timeout: 15))
        snapshot("4-profile-history")
    }

    func testPlayingAsAGroupRecordsEveryonesAnswersInGroupHistoryOnly() {
        addPerson("Maya")
        addPerson("Sam")
        app.buttons["add-profile"].tap()
        app.buttons["New Group"].tap()
        let groupName = field("group-name")
        XCTAssertTrue(groupName.waitForExistence(timeout: 15))
        groupName.tap()
        groupName.typeText("Friends")
        app.buttons["member-Maya"].tap()
        app.buttons["member-Sam"].tap()
        app.buttons["group-create"].tap()
        XCTAssertTrue(app.buttons["profile-row-Friends"].waitForExistence(timeout: 15))

        openTab("Game")
        app.buttons["game-group-Friends"].tap()
        app.buttons["start-game"].tap()

        lockInOption(0, as: "Maya")
        lockInOption(1, as: "Sam")
        XCTAssertTrue(app.staticTexts["reveal-header"].waitForExistence(timeout: 15))

        app.buttons["end-game"].tap()
        app.buttons["End Game"].tap()
        XCTAssertTrue(app.navigationBars["Party Game"].waitForExistence(timeout: 15))

        openTab("Profiles")
        app.buttons["profile-row-Friends"].tap()
        XCTAssertTrue(app.staticTexts["Maya: A big wet kiss from Great Aunt Sharon."].waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts["Sam: A cloud that rains diarrhea."].exists)

        app.navigationBars.buttons["Profiles"].tap()
        XCTAssertTrue(app.buttons["profile-row-Maya"].waitForExistence(timeout: 15))
        app.buttons["profile-row-Maya"].tap()
        XCTAssertTrue(app.staticTexts["Nothing asked yet. Swipe a card right on the Cards tab."].waitForExistence(timeout: 15))
    }

    func testStartingAGameWithNoPlayersSelectedShowsAClearMessage() {
        openTab("Game")

        app.buttons["start-game"].tap()

        XCTAssertTrue(app.staticTexts["Pick at least one player"].waitForExistence(timeout: 15))
    }
}
