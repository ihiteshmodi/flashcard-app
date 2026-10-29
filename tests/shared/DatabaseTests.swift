import XCTest
@testable import FlashcardsCore

final class DatabaseTests: XCTestCase {
    func testAFreshDatabaseIsMigratedToTheLatestSchema() throws {
        let db = try Database.inMemory()

        try Migrator.current.migrate(db)

        XCTAssertEqual(try db.schemaVersion(), Migrator.current.latestVersion)
        XCTAssertTrue(try db.tableNames().isSuperset(of: ["deck", "card", "profile", "card_state", "answer", "group_member"]))
    }

    func testMigratingTwiceChangesNothing() throws {
        let db = try Database.inMemory()
        try Migrator.current.migrate(db)
        try db.run("INSERT INTO profile(id, kind, name, emoji, name_key, created_at) VALUES('p1', 'person', 'Maya', 'x', 'maya', 0)")

        try Migrator.current.migrate(db)

        XCTAssertEqual(try db.count("SELECT COUNT(*) AS n FROM profile"), 1)
    }

    func testAnOlderDatabaseIsUpgradedAndKeepsItsData() throws {
        let db = try Database.inMemory()
        try Migrator.current.migrate(db)
        try db.run("INSERT INTO profile(id, kind, name, emoji, name_key, created_at) VALUES('p1', 'person', 'Maya', 'x', 'maya', 0)")
        let addNotes = MigrationStep(version: 2) { try $0.script("ALTER TABLE profile ADD COLUMN note TEXT") }
        let nextRelease = Migrator(steps: Migrator.current.steps + [addNotes])

        try nextRelease.migrate(db)

        XCTAssertEqual(try db.schemaVersion(), 2)
        XCTAssertEqual(try db.firstRow("SELECT name FROM profile")?.string("name"), "Maya")
    }

    func testAFailedStepRollsEverythingBack() throws {
        let db = try Database.inMemory()
        let broken = Migrator(steps: [
            MigrationStep(version: 1) { try $0.script("CREATE TABLE a(id INTEGER)") },
            MigrationStep(version: 2) { _ in throw DatabaseError.failed("boom") },
        ])

        XCTAssertThrowsError(try broken.migrate(db))

        XCTAssertEqual(try db.schemaVersion(), 0)
        XCTAssertFalse(try db.tableNames().contains("a"))
    }

    func testForeignKeysCascadeWhenAProfileIsDeleted() throws {
        let db = try Database.inMemory()
        try Migrator.current.migrate(db)
        try db.run("INSERT INTO profile(id, kind, name, emoji, name_key, created_at) VALUES('p1', 'person', 'Maya', 'x', 'maya', 0)")
        try db.run("INSERT INTO deck(id, title, sort_order, is_builtin) VALUES('d', 'D', 0, 1)")
        try db.run("INSERT INTO card(id, deck_id, kind, prompt, sort_order, is_builtin, created_at) VALUES('c', 'd', 'question', 'Q', 1, 1, 0)")
        try db.run("INSERT INTO card_state(profile_id, card_id, status, updated_at) VALUES('p1', 'c', 'asked', 0)")

        try db.run("DELETE FROM profile WHERE id = 'p1'")

        XCTAssertEqual(try db.count("SELECT COUNT(*) AS n FROM card_state"), 0)
    }

    func testRevisionChangesAfterAWrite() throws {
        let db = try Database.inMemory()
        try Migrator.current.migrate(db)
        let before = db.revision

        try db.run("INSERT INTO setting(key, value) VALUES('k', 'v')")

        XCTAssertGreaterThan(db.revision, before)
    }
}
