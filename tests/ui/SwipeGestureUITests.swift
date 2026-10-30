import XCTest

final class SwipeGestureUITests: FlashcardsUITestCase {
    private func dragTopCard(toTheRight: Bool) {
        let card = app.descendants(matching: .any)["card-demo-deep-001"].firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 15))
        let start = card.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let end = card.coordinate(withNormalizedOffset: CGVector(dx: toTheRight ? 1.3 : -0.3, dy: 0.5))
        start.press(forDuration: 0.1, thenDragTo: end)
    }

    func testDraggingACardRightAsksForTheAnswerJustLikeTheTickButton() {
        addPerson("Maya")
        openTab("Cards")

        dragTopCard(toTheRight: true)

        XCTAssertTrue(app.buttons["save-answer"].waitForExistence(timeout: 15), "the note sheet should open after a right swipe")
        app.buttons["not-now"].tap()
        XCTAssertTrue(app.staticTexts["progress"].label.hasPrefix("1 of 6 asked"))
    }

    func testDraggingACardLeftSkipsItWithoutAskingForAnAnswer() {
        addPerson("Maya")
        openTab("Cards")

        dragTopCard(toTheRight: false)

        XCTAssertTrue(app.staticTexts["progress"].waitForExistence(timeout: 15))
        XCTAssertFalse(app.buttons["save-answer"].exists)
        XCTAssertTrue(app.staticTexts["progress"].label.hasPrefix("0 of 6 asked"))
    }
}
