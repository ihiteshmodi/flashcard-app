import XCTest

final class GameUITests: FlashcardsUITestCase {
    private func snapshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func startGame(with names: [String]) {
        openTab("Game")
        for (index, name) in names.enumerated() {
            if index >= 3 {
                app.buttons["add-player"].tap()
            }
            let nameField = field("player-name-\(index)")
            XCTAssertTrue(nameField.waitForExistence(timeout: 15))
            nameField.tap()
            nameField.typeText(name)
        }
        for setID in ["main-2022", "intl", "uk", "can", "aus"] {
            let toggle = app.switches["set-\(setID)"]
            if toggle.exists, toggle.value as? String == "1" { toggle.tap() }
        }
        snapshot("1-setup")
        app.buttons["start-game"].tap()
    }

    private func passedTo(_ name: String, file: StaticString = #filePath, line: UInt = #line) {
        let label = app.staticTexts["pass-to"]
        XCTAssertTrue(label.waitForExistence(timeout: 15), file: file, line: line)
        XCTAssertEqual(label.label, name, file: file, line: line)
    }

    private func playFirstCard(as name: String) {
        passedTo(name)
        XCTAssertEqual(app.staticTexts["pass-to"].label, name)
        if name == "Sam" { snapshot("2-pass-the-phone") }
        app.buttons["ready"].tap()
        XCTAssertFalse(app.buttons["ready"].exists)
        let card = app.buttons["hand-card-0"]
        XCTAssertTrue(card.waitForExistence(timeout: 15))
        XCTAssertFalse(app.buttons["play-cards"].isEnabled, "nothing is chosen yet")
        card.tap()
        if name == "Sam" { snapshot("3-choose-a-card") }
        app.buttons["play-cards"].tap()
    }

    private func playARound() {
        playFirstCard(as: "Sam")
        playFirstCard(as: "Lee")
        passedTo("Maya")
        app.buttons["ready"].tap()
        XCTAssertTrue(app.buttons["play-0"].waitForExistence(timeout: 15))
        XCTAssertFalse(app.buttons["pick-winner"].isEnabled, "no play is chosen yet")
        app.buttons["play-0"].tap()
        snapshot("4-the-czar-judges")
        app.buttons["pick-winner"].tap()
    }

    func testAFullRoundIsPlayedOnOnePhoneAndTheNextRoundPassesTheCzarOn() {
        startGame(with: ["Maya", "Sam", "Lee"])

        playARound()

        let winner = app.staticTexts["round-winner"]
        XCTAssertTrue(winner.waitForExistence(timeout: 15))
        XCTAssertEqual(winner.label, "Sam wins the round")
        snapshot("5-round-result")
        app.buttons["next-round"].tap()
        passedTo("Lee")
    }

    func testTheScoresShowTheWinnerAndEndingTheGameShowsTheFinalScores() {
        startGame(with: ["Maya", "Sam", "Lee"])
        playARound()
        XCTAssertTrue(app.buttons["next-round"].waitForExistence(timeout: 15))

        app.buttons["scores"].tap()
        let sam = app.descendants(matching: .any)["score-Sam"].firstMatch
        XCTAssertTrue(sam.waitForExistence(timeout: 15))
        XCTAssertTrue(sam.label.contains("1 point"), sam.label)
        snapshot("6-scores")
        app.buttons["scores-done"].tap()

        app.buttons["end-game"].tap()
        app.buttons["End Game"].tap()

        XCTAssertTrue(app.buttons["start-game"].waitForExistence(timeout: 15), "there is no game to continue")
        XCTAssertTrue(app.descendants(matching: .any)["score-Sam"].firstMatch.exists, "the final scores are shown")
    }

    func testAGameWithTwoPlayersIsRefusedWithTheReason() {
        openTab("Game")
        for (index, name) in ["Maya", "Sam"].enumerated() {
            let nameField = field("player-name-\(index)")
            XCTAssertTrue(nameField.waitForExistence(timeout: 15))
            nameField.tap()
            nameField.typeText(name)
        }

        app.buttons["start-game"].tap()

        XCTAssertTrue(app.staticTexts["Add at least 3 players"].waitForExistence(timeout: 15))
    }
}
