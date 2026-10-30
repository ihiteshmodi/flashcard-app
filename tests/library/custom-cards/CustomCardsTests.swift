import XCTest
@testable import FlashcardsCore

final class CustomCardsTests: XCTestCase {
    func testAddingAQuestionPutsItInMyCardsAndInTheStack() throws {
        let world = try World()
        let maya = try world.person("Maya")
        let session = try world.app.session(for: maya.id)

        let card = try world.app.customCards.add(kind: .question, prompt: "What is your comfort movie?")
        try session.syncWithLibrary()

        XCTAssertEqual(try world.app.customCards.cards(), [card])
        XCTAssertEqual(session.stack, [card])
        XCTAssertFalse(card.isBuiltIn)
    }

    func testAMyCardsDeckAppearsInDeckChoicesOnlyOnceItHasACard() throws {
        let world = try World()
        let maya = try world.person("Maya")
        XCTAssertEqual(try world.app.decks.rows(for: maya.id), [])

        try world.app.customCards.add(kind: .question, prompt: "Q")

        XCTAssertEqual(try world.app.decks.rows(for: maya.id).map(\.deck.title), ["My Cards"])
    }

    func testANewCardIsUnaskedForEveryProfile() throws {
        let world = try World()
        let maya = try world.person("Maya")
        let sam = try world.person("Sam")
        let group = try world.app.groups.createGroup(name: "Friends", memberIDs: [maya.id])
        try world.deck("Deep Talk", cards: ["Q1"])
        try world.markAsked(["Q1"], for: maya)

        try world.app.customCards.add(kind: .question, prompt: "What is your comfort movie?")

        for profile in [maya, sam, group] {
            XCTAssertEqual(try world.app.session(for: profile.id).stack.map(\.prompt).contains("What is your comfort movie?"), true)
        }
    }

    func testTheQuestionTextIsRequired() throws {
        let world = try World()

        XCTAssertThrowsError(try world.app.customCards.add(kind: .question, prompt: "  ")) {
            XCTAssertEqual($0.localizedDescription, "Enter the question")
        }
        XCTAssertEqual(try world.app.customCards.cards(), [])
    }

    func testAThisOrThatCardNeedsExactlyTwoOptions() throws {
        let world = try World()

        let card = try world.app.customCards.add(kind: .thisOrThat, prompt: "Hot drink", options: ["Coffee", " Tea "])

        XCTAssertEqual(card.options, ["Coffee", "Tea"])
        XCTAssertThrowsError(try world.app.customCards.add(kind: .thisOrThat, prompt: "Hot drink", options: ["Coffee"]))
        XCTAssertThrowsError(try world.app.customCards.add(kind: .thisOrThat, prompt: "Hot drink", options: ["A", "B", "C"]))
    }

    func testAMultipleChoiceCardNeedsTwoToFourOptions() throws {
        let world = try World()

        XCTAssertThrowsError(try world.app.customCards.add(kind: .multipleChoice, prompt: "Pick", options: ["only one", " "])) {
            XCTAssertEqual($0.localizedDescription, "Add at least two options")
        }
        XCTAssertThrowsError(try world.app.customCards.add(kind: .multipleChoice, prompt: "Pick", options: ["a", "b", "c", "d", "e"])) {
            XCTAssertEqual($0.localizedDescription, "Use at most four options")
        }
        XCTAssertEqual(try world.app.customCards.add(kind: .multipleChoice, prompt: "Pick", options: ["a", "b", "c"]).options.count, 3)
    }

    func testTopicsAndUpgradesCannotBeAddedButDaresCan() throws {
        let world = try World()

        XCTAssertThrowsError(try world.app.customCards.add(kind: .topic, prompt: "Do something"))
        XCTAssertThrowsError(try world.app.customCards.add(kind: .upgrade, prompt: "Do something"))
        XCTAssertNoThrow(try world.app.customCards.add(kind: .dare, prompt: "Do something"))
    }

    func testEditingChangesTheTextAndKeepsAnswers() throws {
        let world = try World()
        let maya = try world.person("Maya")
        let card = try world.app.customCards.add(kind: .question, prompt: "What is your comfort movie?")
        try world.app.session(for: maya.id).swipeRight()
        try world.app.answers.save(profileID: maya.id, cardID: card.id, text: "Amelie", pickIndex: nil)

        try world.app.customCards.edit(card.id, prompt: "What is your comfort show?")

        XCTAssertEqual(try world.app.customCards.cards().first?.prompt, "What is your comfort show?")
        XCTAssertEqual(try world.app.answers.answer(profileID: maya.id, cardID: card.id)?.text, "Amelie")
        XCTAssertEqual(try world.app.session(for: maya.id).progress.asked, 1)
    }

    func testEditingKeepsTheCardValid() throws {
        let world = try World()
        let card = try world.app.customCards.add(kind: .thisOrThat, prompt: "Hot drink", options: ["Coffee", "Tea"])

        XCTAssertThrowsError(try world.app.customCards.edit(card.id, prompt: "Hot drink", options: ["Coffee"]))
        XCTAssertThrowsError(try world.app.customCards.edit(card.id, prompt: "", options: ["Coffee", "Tea"]))
    }

    func testDeletingRemovesTheCardAndItsAnswersAfterReportingThem() throws {
        let world = try World()
        let maya = try world.person("Maya")
        let card = try world.app.customCards.add(kind: .question, prompt: "What is your comfort movie?")
        try world.app.session(for: maya.id).swipeRight()
        try world.app.answers.save(profileID: maya.id, cardID: card.id, text: "Amelie", pickIndex: nil)

        XCTAssertEqual(try world.app.customCards.answersLost(ifDeleting: card.id), 1)
        try world.app.customCards.delete(card.id)

        XCTAssertEqual(try world.app.customCards.cards(), [])
        XCTAssertEqual(try world.db.count("SELECT COUNT(*) AS n FROM answer"), 0)
        XCTAssertEqual(try world.db.count("SELECT COUNT(*) AS n FROM card_state"), 0)
    }

    func testBundledCardsCannotBeEditedOrDeleted() throws {
        let world = try World()
        let bundled = try XCTUnwrap(try world.deck("Deep Talk", cards: ["Q1"]).first)

        XCTAssertThrowsError(try world.app.customCards.edit(bundled.id, prompt: "Changed")) {
            XCTAssertEqual($0 as? CustomCardError, .builtInCard)
        }
        XCTAssertThrowsError(try world.app.customCards.delete(bundled.id))
        XCTAssertEqual(try world.card(id: bundled.id).prompt, "Q1")
    }

    func testMyCardsKeepTheOrderTheyWereAdded() throws {
        let world = try World()

        try world.app.customCards.add(kind: .question, prompt: "First")
        try world.app.customCards.add(kind: .question, prompt: "Second")

        XCTAssertEqual(try world.app.customCards.cards().map(\.prompt), ["First", "Second"])
    }
}
