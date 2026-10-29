import XCTest
@testable import FlashcardsCore

final class AnswersTests: XCTestCase {
    private func world() throws -> (World, Profile, CardSession) {
        let world = try World()
        try world.deck("Deep Talk", cards: ["Where would you live?", "Q2", "Q3"])
        let maya = try world.person("Maya")
        return (world, maya, try world.app.session(for: maya.id))
    }

    func testASavedAnswerAppearsInHistoryWithItsCard() throws {
        let (world, maya, session) = try world()
        let card = try XCTUnwrap(try session.swipeRight())

        try world.app.answers.save(profileID: maya.id, cardID: card.id, text: "Portugal", pickIndex: nil)

        let entry = try XCTUnwrap(try world.app.answers.history(profileID: maya.id).first)
        XCTAssertEqual(entry.card.prompt, "Where would you live?")
        XCTAssertEqual(entry.answer?.text, "Portugal")
    }

    func testAskingWithoutSavingStillCountsAndShowsNoAnswer() throws {
        let (world, maya, session) = try world()
        try session.swipeRight()

        let entry = try XCTUnwrap(try world.app.answers.history(profileID: maya.id).first)

        XCTAssertNil(entry.answer)
    }

    func testAnEmptyNoteIsTreatedAsNoAnswer() throws {
        let (world, maya, session) = try world()
        let card = try XCTUnwrap(try session.swipeRight())

        try world.app.answers.save(profileID: maya.id, cardID: card.id, text: "   ", pickIndex: nil)

        XCTAssertNil(try world.app.answers.answer(profileID: maya.id, cardID: card.id))
    }

    func testClearingANoteRemovesTheEarlierAnswer() throws {
        let (world, maya, session) = try world()
        let card = try XCTUnwrap(try session.swipeRight())
        try world.app.answers.save(profileID: maya.id, cardID: card.id, text: "Portugal", pickIndex: nil)

        try world.app.answers.save(profileID: maya.id, cardID: card.id, text: "", pickIndex: nil)

        XCTAssertNil(try world.app.answers.answer(profileID: maya.id, cardID: card.id))
    }

    func testMultipleChoiceRecordsThePickedOption() throws {
        let world = try World()
        let maya = try world.person("Maya")
        try world.deck("Pairs", cards: ["Spinach in their teeth. Do you..."], kind: .multipleChoice,
                       options: ["Tell them instantly", "Pretend you did not notice", "Put food in your own teeth"])
        let card = try XCTUnwrap(try world.app.session(for: maya.id).swipeRight())

        try world.app.answers.save(profileID: maya.id, cardID: card.id, text: nil, pickIndex: 1)

        let answer = try XCTUnwrap(try world.app.answers.answer(profileID: maya.id, cardID: card.id))
        XCTAssertEqual(answer.pickLabel(for: card), "b: Pretend you did not notice")
    }

    func testThisOrThatRecordsThePickedSideAndANote() throws {
        let world = try World()
        let maya = try world.person("Maya")
        try world.deck("Pairs", cards: ["Text first or end the call"], kind: .thisOrThat,
                       options: ["Never text first", "Never end a call first"])
        let card = try XCTUnwrap(try world.app.session(for: maya.id).swipeRight())

        try world.app.answers.save(profileID: maya.id, cardID: card.id, text: "she laughed", pickIndex: 1)

        let answer = try XCTUnwrap(try world.app.answers.answer(profileID: maya.id, cardID: card.id))
        XCTAssertEqual(answer.pickLabel(for: card), "Never end a call first")
        XCTAssertEqual(answer.text, "she laughed")
    }

    func testAPickOutsideTheOptionsIsIgnored() throws {
        let world = try World()
        let maya = try world.person("Maya")
        try world.deck("Pairs", cards: ["A or B"], kind: .thisOrThat, options: ["A", "B"])
        let card = try XCTUnwrap(try world.app.session(for: maya.id).swipeRight())

        try world.app.answers.save(profileID: maya.id, cardID: card.id, text: nil, pickIndex: 5)

        XCTAssertNil(try world.app.answers.answer(profileID: maya.id, cardID: card.id))
    }

    func testMultipleChoiceWithoutAPickIsStillAsked() throws {
        let world = try World()
        let maya = try world.person("Maya")
        try world.deck("Pairs", cards: ["Spinach?"], kind: .multipleChoice, options: ["a1", "b1"])

        try world.app.session(for: maya.id).swipeRight()

        XCTAssertEqual(try world.app.answers.history(profileID: maya.id).count, 1)
        XCTAssertNil(try world.app.answers.history(profileID: maya.id).first?.answer)
    }

    func testDaresDoNotCollectAnswers() {
        XCTAssertFalse(CardKind.dare.collectsAnswer)
        XCTAssertTrue(CardKind.question.collectsAnswer)
        XCTAssertTrue(CardKind.multipleChoice.collectsAnswer)
    }

    func testHistoryListsNewestFirstAndCanFilterToAnswers() throws {
        let (world, maya, session) = try world()
        let first = try XCTUnwrap(try session.swipeRight())
        try session.swipeRight()
        try session.swipeRight()
        try world.app.answers.save(profileID: maya.id, cardID: first.id, text: "Portugal", pickIndex: nil)

        let all = try world.app.answers.history(profileID: maya.id)
        let answered = try world.app.answers.history(profileID: maya.id, onlyWithAnswers: true)

        XCTAssertEqual(all.map(\.card.prompt), ["Q3", "Q2", "Where would you live?"])
        XCTAssertEqual(answered.map(\.card.prompt), ["Where would you live?"])
    }

    func testEditingAnAnswerReplacesIt() throws {
        let (world, maya, session) = try world()
        let card = try XCTUnwrap(try session.swipeRight())
        try world.app.answers.save(profileID: maya.id, cardID: card.id, text: "Portugal", pickIndex: nil)

        try world.app.answers.save(profileID: maya.id, cardID: card.id, text: "Portugal or Spain", pickIndex: nil)

        XCTAssertEqual(try world.app.answers.history(profileID: maya.id).first?.answer?.text, "Portugal or Spain")
        XCTAssertEqual(try world.db.count("SELECT COUNT(*) AS n FROM answer"), 1)
    }

    func testUndoKeepsTheAnswerButHidesTheEntryUntilTheCardIsAskedAgain() throws {
        let (world, maya, session) = try world()
        let card = try XCTUnwrap(try session.swipeRight())
        try world.app.answers.save(profileID: maya.id, cardID: card.id, text: "Portugal", pickIndex: nil)

        try session.undo()
        XCTAssertEqual(try world.app.answers.history(profileID: maya.id), [])
        XCTAssertEqual(try world.app.answers.answer(profileID: maya.id, cardID: card.id)?.text, "Portugal")

        try session.redo()
        XCTAssertEqual(try world.app.answers.history(profileID: maya.id).first?.answer?.text, "Portugal")
    }

    func testAskingTheSameCardAgainAfterUndoPrefillsTheSavedAnswer() throws {
        let (world, maya, session) = try world()
        let card = try XCTUnwrap(try session.swipeRight())
        try world.app.answers.save(profileID: maya.id, cardID: card.id, text: "Lisbon", pickIndex: nil)
        try session.undo()

        let again = try XCTUnwrap(try session.swipeRight())

        XCTAssertEqual(try world.app.answers.answer(profileID: maya.id, cardID: again.id)?.text, "Lisbon")
    }

    func testSkippedCardsAreNotInTheHistory() throws {
        let (world, maya, session) = try world()
        try session.swipeLeft()
        try world.saveAnswerDirectly("Portugal", card: "Where would you live?", for: maya)

        XCTAssertEqual(try world.app.answers.history(profileID: maya.id), [])
    }

    func testAnswersAreScopedToTheProfileThatSavedThem() throws {
        let (world, maya, session) = try world()
        let sam = try world.person("Sam")
        let card = try XCTUnwrap(try session.swipeRight())
        try world.app.answers.save(profileID: maya.id, cardID: card.id, text: "Portugal", pickIndex: nil)

        XCTAssertNil(try world.app.answers.answer(profileID: sam.id, cardID: card.id))
    }

    func testPeopleAnswersAreNotLabelledWithAnAnswerer() throws {
        let (world, maya, session) = try world()
        let card = try XCTUnwrap(try session.swipeRight())

        try world.app.answers.save(profileID: maya.id, cardID: card.id, text: "Portugal", pickIndex: nil, answeredBy: "Sam")

        XCTAssertNil(try world.app.answers.answer(profileID: maya.id, cardID: card.id)?.answeredBy)
    }
}
