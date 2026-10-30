import XCTest
@testable import FlashcardsCore

/// The public starter deck ships in the repository, so these tests never skip.
final class StarterDeckTests: XCTestCase {
    private func starterData() throws -> Data {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<4 { root = root.deletingLastPathComponent() }
        return try Data(contentsOf: root.appendingPathComponent("app/resources/StarterDecks.json"))
    }

    func testTheStarterDeckGivesAFreshInstallTwentyOneQuestionsAndMore() throws {
        let world = try World()

        try world.app.loadSeed(try starterData())

        let decks = try world.app.catalog.decks()
        XCTAssertEqual(decks.map(\.deck.title), ["21 Questions"])
        XCTAssertGreaterThan(decks[0].cardCount, 21)
        XCTAssertEqual(decks[0].categories, ["Values & Character", "Ambition & Personal Growth", "Connection & Relationships", "Inner World & Perspective"])
    }

    func testANewProfileCanSwipeThroughTheStarterDeck() throws {
        let world = try World()
        try world.app.loadSeed(try starterData())
        let maya = try world.person("Maya")
        let session = try world.app.session(for: maya.id)

        XCTAssertEqual(session.progress.total, try world.app.catalog.decks()[0].cardCount)
        XCTAssertNotNil(try session.swipeRight())
    }

    func testEveryStarterCardIsAPlainQuestionWithAStableUniqueId() throws {
        let world = try World()
        try world.app.loadSeed(try starterData())

        let cards = try world.db.rows("SELECT * FROM card WHERE is_builtin = 1").map(Card.init(row:))

        XCTAssertEqual(Set(cards.map(\.id)).count, cards.count)
        XCTAssertTrue(cards.allSatisfy { $0.kind == .question && !$0.prompt.isEmpty })
        XCTAssertTrue(cards.allSatisfy { $0.id.hasPrefix("21-questions-") })
    }

    func testLoadingTheStarterDeckBeforeAPrivateSeedWithTheSameIdsDuplicatesNothing() throws {
        let world = try World()
        let starter = try starterData()
        try world.app.loadSeed(starter)
        let before = try world.db.count("SELECT COUNT(*) AS n FROM card")

        try world.app.loadSeed(starter)

        XCTAssertEqual(try world.db.count("SELECT COUNT(*) AS n FROM card"), before)
    }

    func testBothSeedsAreLoadedAgainAfterAnImport() throws {
        let source = try World()
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("starter-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let backupFile = folder.appendingPathComponent("empty.sqlite")
        try source.app.backup.export(to: backupFile)
        let target = try World()
        try target.app.loadSeed(try starterData())
        try target.app.loadSeed(Data(#"{"version":1,"decks":[{"id":"extra","title":"Extra","cards":[{"id":"extra-1","kind":"question","prompt":"Another"}]}]}"#.utf8))

        try target.app.backup.restore(from: backupFile)

        XCTAssertEqual(try target.card(id: "extra-1").prompt, "Another")
        XCTAssertNoThrow(try target.card(id: "21-questions-001"))
    }
}
