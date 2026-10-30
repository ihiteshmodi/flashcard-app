import XCTest
@testable import FlashcardsCore

final class CustomCardLabelsTests: XCTestCase {
    func testDefaultsAreMyCardsNoCategoryEveryoneSafeAnyone() throws {
        let world = try World()

        let card = try world.app.customCards.add(kind: .question, prompt: "What is your comfort movie?")

        XCTAssertEqual(card.deckID, "my-cards")
        XCTAssertNil(card.category)
        XCTAssertNil(card.detail)
        XCTAssertEqual(card.audience, .everyone)
        XCTAssertEqual(card.spice, .safe)
        XCTAssertEqual(card.perspective, .anyone)
    }

    func testACardCanJoinABuiltInDeckUnderACategoryAndStaysEditableAndDeletable() throws {
        let world = try World()
        try world.deck("21 Questions", cards: ["Bundled"])

        let card = try world.app.customCards.add(
            kind: .question, prompt: "What is your biggest fear?", deckID: "21-questions", category: "Inner World")

        XCTAssertEqual(card.deckID, "21-questions")
        XCTAssertEqual(card.category, "Inner World")
        XCTAssertFalse(card.isBuiltIn)
        XCTAssertEqual(try world.app.customCards.categories(inDeck: "21-questions"), ["Inner World"])
        try world.app.customCards.edit(card.id, prompt: "What scares you most?", deckID: "21-questions", category: "Inner World")
        XCTAssertEqual(try world.card(id: card.id).prompt, "What scares you most?")
        try world.app.customCards.delete(card.id)
        XCTAssertEqual(try world.app.customCards.cards(), [])
    }

    func testMyCardsListEveryOwnCardInAnyDeck() throws {
        let world = try World()
        try world.deck("21 Questions", cards: ["Bundled"])
        let mine = try world.app.customCards.add(kind: .question, prompt: "Mine", deckID: "21-questions")
        let other = try world.app.customCards.add(kind: .question, prompt: "Other")

        XCTAssertEqual(try world.app.customCards.cards(), [mine, other])
    }

    func testMyCardInABuiltInDeckSurvivesABundledDeckUpdate() throws {
        let world = try World()
        let seed = Data("""
        {"version":1,"decks":[{"id":"d","title":"D","cards":[{"id":"c1","kind":"question","prompt":"Bundled"}]}]}
        """.utf8)
        try world.app.loadSeed(seed)
        let mine = try world.app.customCards.add(kind: .question, prompt: "Mine", deckID: "d")

        try world.app.loadSeed(seed)

        XCTAssertEqual(try world.card(id: mine.id).prompt, "Mine")
    }

    func testADareCanCarryADetailAndNeedsNoOptions() throws {
        let world = try World()

        let dare = try world.app.customCards.add(kind: .dare, prompt: "Hold hands for a minute", detail: "no talking")

        XCTAssertEqual(dare.kind, .dare)
        XCTAssertEqual(dare.detail, "no talking")
        XCTAssertFalse(dare.kind.collectsAnswer)
    }

    func testATipLineIsKept() throws {
        let world = try World()

        let card = try world.app.customCards.add(kind: .question, prompt: "Best trip?", detail: "Why it works: it invites a story")

        XCTAssertEqual(card.detail, "Why it works: it invites a story")
    }

    func testMyLabelsDecideWhoSeesMyCard() throws {
        let table: [(Audience, Spice, Closeness, Bool)] = [
            (.everyone, .safe, .friend, true),
            (.women, .safe, .friend, true),
            (.men, .safe, .friend, false),
            (.couples, .safe, .friend, false),
            (.couples, .safe, .dating, true),
            (.everyone, .explicit, .dating, false),
            (.everyone, .explicit, .partner, true),
        ]
        for (audience, spice, closeness, shown) in table {
            let world = try World()
            let maya = try world.person("Maya", gender: .woman, closeness)
            try world.app.customCards.add(kind: .question, prompt: "My card", audience: audience, spice: spice)
            try world.app.session(for: maya.id).syncWithLibrary()

            XCTAssertEqual(try world.stack(for: maya).contains("My card"), shown, "\(audience) \(spice) \(closeness)")
        }
    }

    func testEditingLabelsUpdatesEveryOpenStack() throws {
        let world = try World()
        let maya = try world.person("Maya", gender: .woman, .friend)
        let card = try world.app.customCards.add(kind: .question, prompt: "My card", audience: .couples)
        try world.app.session(for: maya.id).syncWithLibrary()
        XCTAssertFalse(try world.stack(for: maya).contains("My card"))

        try world.app.customCards.edit(card.id, prompt: "My card", audience: .everyone)
        try world.app.session(for: maya.id).syncWithLibrary()

        XCTAssertTrue(try world.stack(for: maya).contains("My card"))
    }

    func testACardNeedsTextAndAKnownDeck() throws {
        let world = try World()

        XCTAssertThrowsError(try world.app.customCards.add(kind: .question, prompt: "  ")) {
            XCTAssertEqual($0 as? CustomCardError, .emptyPrompt)
        }
        XCTAssertThrowsError(try world.app.customCards.add(kind: .question, prompt: "Q", deckID: "nope")) {
            XCTAssertEqual($0 as? CustomCardError, .unknownDeck)
        }
    }

    func testACategoryWithMyCardsIsSavedInsideMyCards() throws {
        let world = try World()

        let card = try world.app.customCards.add(kind: .question, prompt: "Q", category: "Fun")

        XCTAssertEqual(card.deckID, "my-cards")
        XCTAssertEqual(card.category, "Fun")
    }

    func testOwnCardsCreatedBeforeLabelsExistedGetTheDefaults() throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("v1-\(UUID().uuidString).sqlite")
        defer { try? FileManager.default.removeItem(at: file) }
        let db = try Database(path: file.path)
        try Migrator(steps: [Migrator.current.steps[0]]).migrate(db)
        try db.run("INSERT INTO card(id, deck_id, category, kind, prompt, detail, options, sort_order, is_builtin, created_at) VALUES('c', 'my-cards', NULL, 'question', 'Old', NULL, '[]', 1, 0, 0)")

        try Migrator.current.migrate(db)

        let card = Card(row: try XCTUnwrap(try db.firstRow("SELECT * FROM card WHERE id = 'c'")))
        XCTAssertEqual([card.audience.rawValue, card.spice.rawValue, card.perspective.rawValue], ["everyone", "safe", "anyone"])
    }
}
