import XCTest
@testable import FlashcardsCore

final class ChooseDecksTests: XCTestCase {
    private func world() throws -> World {
        let world = try World()
        try world.deck("Deep Talk", cards: ["Q1", "Q2", "Q3"])
        try world.deck("Dares", cards: ["D1", "D2"], kind: .dare)
        return world
    }

    func testNewProfilesDrawFromAllDecks() throws {
        let world = try world()
        let maya = try world.person("Maya")

        let rows = try world.app.decks.rows(for: maya.id)

        XCTAssertEqual(rows.map(\.deck.title), ["Deep Talk", "Dares"])
        XCTAssertEqual(rows.map(\.isOn), [true, true])
        XCTAssertEqual(try world.app.profiles.people().first?.progress.total, 5)
    }

    func testTurningADeckOffRemovesItsCardsFromThatProfilesTotal() throws {
        let world = try world()
        let maya = try world.person("Maya")

        try world.app.decks.setDeck("dares", on: false, for: maya.id)

        XCTAssertEqual(try world.app.decks.rows(for: maya.id).map(\.isOn), [true, false])
        XCTAssertEqual(try world.app.profiles.people().first?.progress.total, 3)
    }

    func testTurningADeckBackOnRestoresItsCards() throws {
        let world = try world()
        let maya = try world.person("Maya")
        try world.app.decks.setDeck("dares", on: false, for: maya.id)

        try world.app.decks.setDeck("dares", on: true, for: maya.id)

        XCTAssertEqual(try world.app.profiles.people().first?.progress.total, 5)
    }

    func testDeckChoiceBelongsToOneProfile() throws {
        let world = try world()
        let maya = try world.person("Maya")
        let sam = try world.person("Sam")

        try world.app.decks.setDeck("dares", on: false, for: maya.id)

        XCTAssertEqual(try world.app.decks.rows(for: sam.id).map(\.isOn), [true, true])
    }

    func testAtLeastOneDeckMustStayOn() throws {
        let world = try world()
        let maya = try world.person("Maya")
        try world.app.decks.setDeck("dares", on: false, for: maya.id)

        XCTAssertThrowsError(try world.app.decks.setDeck("deep-talk", on: false, for: maya.id)) { error in
            XCTAssertEqual(error.localizedDescription, "Keep at least one deck on")
        }
        XCTAssertEqual(try world.app.decks.rows(for: maya.id).map(\.isOn), [true, false])
    }

    func testTurningOffAnAlreadyOffDeckIsHarmless() throws {
        let world = try world()
        let maya = try world.person("Maya")
        try world.app.decks.setDeck("dares", on: false, for: maya.id)

        XCTAssertNoThrow(try world.app.decks.setDeck("dares", on: false, for: maya.id))
    }

    func testDeckRowShowsHowManyCardsAreAsked() throws {
        let world = try world()
        let maya = try world.person("Maya")
        try world.markAsked(["Q1", "Q2"], for: maya)

        let deep = try XCTUnwrap(try world.app.decks.rows(for: maya.id).first)

        XCTAssertEqual(deep.askedCount, 2)
        XCTAssertEqual(deep.cardCount, 3)
    }

    func testDecksWithoutCardsAreNotListed() throws {
        let world = try world()
        let maya = try world.person("Maya")

        XCTAssertFalse(try world.app.decks.rows(for: maya.id).map(\.id).contains("my-cards"))
    }
}
