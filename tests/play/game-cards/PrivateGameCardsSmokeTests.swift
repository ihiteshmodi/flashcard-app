import XCTest
@testable import FlashcardsCore

/// Guards the private card sets. Skipped on a fresh clone, where Generated/game-cards.json is missing or a placeholder.
final class PrivateGameCardsSmokeTests: XCTestCase {
    private func library() throws -> GameCardLibrary {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<4 { root = root.deletingLastPathComponent() }
        let family = try Data(contentsOf: root.appendingPathComponent("app/resources/GameCards.json"))
        guard let extra = try? Data(contentsOf: root.appendingPathComponent("Generated/game-cards.json")) else {
            throw XCTSkip("No Generated/game-cards.json")
        }
        let library = try GameCardLibrary(files: [family, extra])
        if library.sets.count < 2 { throw XCTSkip("game-cards.json is the empty placeholder") }
        return library
    }

    func testEveryPrivateSetHasEnoughCardsToPlayAndNoneIsEmpty() throws {
        let library = try library()

        for set in library.sets where set.id != "family" {
            XCTAssertGreaterThanOrEqual(set.blackCards.count, 80, set.title)
            XCTAssertGreaterThanOrEqual(set.whiteCards.count, 450, set.title)
            XCTAssertTrue((set.blackCards.map(\.text) + set.whiteCards.map(\.text)).allSatisfy { !$0.isEmpty }, set.title)
        }
    }

    func testEveryPrivateBlackCardHasABlankIsAQuestionOrAsksForMoreThanOneCard() throws {
        for set in try library().sets {
            for card in set.blackCards {
                XCTAssertTrue(card.text.contains("_____") || card.text.hasSuffix("?") || card.pick > 1, card.text)
            }
        }
    }

    func testEditionsThatShareCardsDealEachCardOnce() throws {
        let library = try library()
        let all = Set(library.sets.map(\.id))

        let dealt = library.whiteCards(in: all)

        XCTAssertLessThan(dealt.count, library.sets.reduce(0) { $0 + $1.whiteCards.count })
        XCTAssertEqual(Set(dealt.map { $0.text.lowercased() }).count, dealt.count)
    }
}
