import XCTest
@testable import FlashcardsCore

final class BrowseDecksTests: XCTestCase {
    private let seed = """
    {"version":1,"decks":[
      {"id":"deep","title":"Deep Talk","cards":[
        {"id":"deep-001","category":"Values","kind":"question","prompt":"Q1"},
        {"id":"deep-002","category":"Values","kind":"question","prompt":"Q2"},
        {"id":"deep-003","category":"Growth","kind":"question","prompt":"Q3"}]},
      {"id":"plain","title":"Plain","cards":[{"id":"plain-001","kind":"question","prompt":"P1"}]},
      {"id":"empty","title":"Empty","cards":[]}
    ]}
    """

    func testBundledDecksListTheirCardCountAndCategoriesInSourceOrder() throws {
        let world = try World()
        try world.app.loadSeed(Data(seed.utf8))

        let decks = try world.app.catalog.decks()

        XCTAssertEqual(decks.map(\.deck.title), ["Deep Talk", "Plain"])
        XCTAssertEqual(decks.first?.cardCount, 3)
        XCTAssertEqual(decks.first?.categories, ["Values", "Growth"])
        XCTAssertEqual(decks.last?.categories, [])
    }

    func testMyCardsAreNotListedAsABundledDeck() throws {
        let world = try World()
        try world.app.customCards.add(kind: .question, prompt: "Mine")

        XCTAssertEqual(try world.app.catalog.decks(), [])
    }

    func testCardsInADeckComeInSourceOrder() throws {
        let world = try World()
        try world.app.loadSeed(Data(seed.utf8))

        XCTAssertEqual(try world.app.catalog.cards(in: "deep").map(\.prompt), ["Q1", "Q2", "Q3"])
    }
}
