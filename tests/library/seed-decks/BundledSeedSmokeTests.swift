import XCTest
@testable import FlashcardsCore

/// Guards the private bundled decks. Skipped on a fresh clone, where Generated/seed.json is only a placeholder.
final class BundledSeedSmokeTests: XCTestCase {
    private func seedData() throws -> Data {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<4 { root = root.deletingLastPathComponent() }
        let url = root.appendingPathComponent("Generated/seed.json")
        guard let data = try? Data(contentsOf: url) else { throw XCTSkip("No Generated/seed.json") }
        let seed = try JSONDecoder().decode(SeedFile.self, from: data)
        if seed.decks.isEmpty { throw XCTSkip("Seed is the empty placeholder") }
        return data
    }

    func testEveryBundledCardLoadsAndIsUsable() throws {
        let world = try World()
        try world.app.loadSeed(try seedData())

        let cards = try world.db.rows("SELECT * FROM card WHERE is_builtin = 1").map(Card.init(row:))

        XCTAssertGreaterThan(cards.count, 0)
        XCTAssertEqual(Set(cards.map(\.id)).count, cards.count, "card ids must be unique")
        XCTAssertTrue(cards.allSatisfy { !$0.prompt.isEmpty })
        XCTAssertTrue(cards.filter { $0.kind == .thisOrThat }.allSatisfy { $0.options.count == 2 })
        XCTAssertTrue(cards.filter { $0.kind == .multipleChoice }.allSatisfy { (2...4).contains($0.options.count) })
    }

    func testLoadingTheBundledDecksTwiceChangesNothing() throws {
        let world = try World()
        let data = try seedData()
        try world.app.loadSeed(data)
        let first = try world.db.count("SELECT COUNT(*) AS n FROM card")

        try world.app.loadSeed(data)

        XCTAssertEqual(try world.db.count("SELECT COUNT(*) AS n FROM card"), first)
    }

    func testANewProfileCanSwipeThroughTheBundledDecks() throws {
        let world = try World(shuffle: { $0.reversed() })
        try world.app.loadSeed(try seedData())
        let maya = try world.person("Maya")
        let session = try world.app.session(for: maya.id)

        XCTAssertFalse(session.hasNoCards)
        XCTAssertNotNil(try session.swipeRight())
    }
}
