import XCTest
@testable import FlashcardsCore

/// The Family Edition ships in the repository, so these tests never skip.
final class FamilyEditionTests: XCTestCase {
    private func familyFile() throws -> Data {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<4 { root = root.deletingLastPathComponent() }
        return try Data(contentsOf: root.appendingPathComponent("app/resources/GameCards.json"))
    }

    private func familySet() throws -> CardSet {
        try XCTUnwrap(try GameCardLibrary(files: [try familyFile()]).sets.first { $0.id == "family" })
    }

    func testTheFamilyEditionShipsWithTheAppAsTheFirstSet() throws {
        let library = try GameCardLibrary(files: [try familyFile()])

        XCTAssertEqual(library.sets.map(\.title), ["Family Edition"])
        XCTAssertEqual(try familySet().blackCards.count, 95)
        XCTAssertEqual(try familySet().whiteCards.count, 505)
    }

    func testEveryFamilyBlackCardHasABlankOrIsAQuestion() throws {
        for card in try familySet().blackCards {
            XCTAssertTrue(card.text.contains("_____") || card.text.hasSuffix("?"), card.text)
        }
    }

    func testNoFamilyCardIsEmptyOrKeepsPdfLeftovers() throws {
        let set = try familySet()
        let texts = set.blackCards.map(\.text) + set.whiteCards.map(\.text)

        XCTAssertTrue(texts.allSatisfy { !$0.isEmpty && !$0.contains("Family Edition") && !$0.contains("\n") })
    }

    func testEveryFamilyCardIsDealtOnceWhenTheSetIsEnabled() throws {
        let library = try GameCardLibrary(files: [try familyFile()])

        XCTAssertEqual(library.blackCards(in: ["family"]).count, 95)
        XCTAssertEqual(library.whiteCards(in: ["family"]).count, 505)
    }

    func testTheCardsTheOcrCouldNotSeeAreFixedByHand() throws {
        let texts = try familySet().blackCards.map(\.text)

        XCTAssertTrue(texts.contains("Time to put on my favorite t-shirt, the one that says “I ♥ _____.”"))
        XCTAssertTrue(texts.contains("New from McDonald’s: it’s the Mc_____ Burger."))
    }
}
