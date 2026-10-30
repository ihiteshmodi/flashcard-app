import XCTest
@testable import FlashcardsCore

final class BackupDatabaseTests: XCTestCase {
    private var folder: URL!

    override func setUpWithError() throws {
        folder = FileManager.default.temporaryDirectory.appendingPathComponent("flashcards-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: folder)
    }

    private func file(_ name: String) -> URL { folder.appendingPathComponent(name) }

    /// A world with two people, a group, deck choices, asked cards, an answer and one custom card.
    private func populated() throws -> (World, Profile) {
        let world = try World()
        try world.deck("Deep Talk", cards: ["Q1", "Q2"])
        try world.deck("Dares", cards: ["D1"], kind: .dare)
        let maya = try world.person("Maya")
        let sam = try world.person("Sam")
        try world.app.groups.createGroup(name: "College Friends", memberIDs: [maya.id, sam.id])
        try world.app.decks.setDeck("dares", on: false, for: maya.id)
        let card = try XCTUnwrap(try world.app.session(for: maya.id).swipeRight())
        try world.app.answers.save(profileID: maya.id, cardID: card.id, text: "Lisbon", pickIndex: nil)
        try world.app.customCards.add(kind: .question, prompt: "What is your comfort movie?")
        return (world, maya)
    }

    private func count(_ url: URL, _ table: String) throws -> Int {
        try Database(path: url.path, readOnly: true).count("SELECT COUNT(*) AS n FROM \(table)")
    }

    func testExportWritesOneSqliteFileWithEverything() throws {
        let (world, _) = try populated()
        let target = file("backup.sqlite")

        try world.app.backup.export(to: target)

        XCTAssertEqual(try count(target, "profile"), 3)
        XCTAssertEqual(try count(target, "group_member"), 2)
        XCTAssertEqual(try count(target, "profile_deck_off"), 1)
        XCTAssertEqual(try count(target, "card_state"), 1)
        XCTAssertEqual(try count(target, "answer"), 1)
        XCTAssertEqual(try count(target, "card WHERE is_builtin = 0"), 1)
    }

    func testExportIncludesTheSwipeMadeJustBefore() throws {
        let (world, maya) = try populated()
        try world.app.session(for: maya.id).swipeRight()
        let target = file("backup.sqlite")

        try world.app.backup.export(to: target)

        XCTAssertEqual(try count(target, "card_state"), 2)
    }

    func testExportingAgainReplacesTheEarlierFile() throws {
        let (world, maya) = try populated()
        let target = file("backup.sqlite")
        try world.app.backup.export(to: target)
        try world.app.session(for: maya.id).swipeRight()

        XCTAssertNoThrow(try world.app.backup.export(to: target))

        XCTAssertEqual(try count(target, "card_state"), 2)
    }

    func testExportCanBeOpenedAsABackup() throws {
        let (world, _) = try populated()
        let target = file("backup.sqlite")
        try world.app.backup.export(to: target)

        let info = try world.app.backup.inspect(target)

        XCTAssertEqual(info, BackupInfo(schemaVersion: Migrator.current.latestVersion, profileCount: 3, answerCount: 1))
    }

    func testTheSuggestedFileNameCarriesTodaysDate() throws {
        let world = try World()

        XCTAssertEqual(world.app.backup.suggestedFileName(timeZone: TimeZone(identifier: "UTC")!), "flashcards-2023-11-14.sqlite")
    }

    func testExportRemembersWhenItLastHappened() throws {
        let (world, _) = try populated()
        XCTAssertNil(world.app.backup.lastExportedAt)

        try world.app.backup.export(to: file("backup.sqlite"))

        XCTAssertNotNil(world.app.backup.lastExportedAt)
    }

    func testImportReplacesAllDataAndKeepsASafetyCopyOfTheOldData() throws {
        let (source, _) = try populated()
        let backupFile = file("from-source.sqlite")
        try source.app.backup.export(to: backupFile)
        let target = try World()
        let safety = file("safety")
        let app = try Flashcards(database: target.db, roles: target.roles, safetyCopyFolder: safety)
        try app.profiles.addPerson(name: "Old Profile")

        let copy = try XCTUnwrap(try app.backup.restore(from: backupFile))

        XCTAssertEqual(try app.profiles.people().map(\.profile.name), ["Maya", "Sam"])
        XCTAssertEqual(try app.profiles.groups().first?.memberCount, 2)
        XCTAssertEqual(try app.answers.history(profileID: try XCTUnwrap(try app.profiles.people().first).id).first?.answer?.text, "Lisbon")
        XCTAssertEqual(try count(copy, "profile"), 1)
    }

    func testImportedDataKeepsWorkingWithNewSessionsAndWrites() throws {
        let (source, maya) = try populated()
        let backupFile = file("from-source.sqlite")
        try source.app.backup.export(to: backupFile)
        let target = try World()
        let stale = try target.app.session(for: target.person("Other").id)

        try target.app.backup.restore(from: backupFile)
        let fresh = try target.app.session(for: maya.id)
        try fresh.swipeRight()

        XCTAssertFalse(stale === fresh)
        XCTAssertEqual(fresh.progress.asked, 2)
    }

    func testBundledCardsAddedByANewerAppArePresentAfterAnImport() throws {
        let (source, _) = try populated()
        let backupFile = file("from-source.sqlite")
        try source.app.backup.export(to: backupFile)
        let target = try World()
        try target.app.loadSeed(Data(#"{"version":1,"decks":[{"id":"fresh","title":"Fresh","cards":[{"id":"fresh-1","kind":"question","prompt":"New card"}]}]}"#.utf8))

        try target.app.backup.restore(from: backupFile)

        XCTAssertEqual(try target.card(id: "fresh-1").prompt, "New card")
    }

    func testAFileThatIsNotAFlashcardsBackupIsRefusedAndNothingChanges() throws {
        let world = try World()
        try world.person("Maya")
        let other = file("other.sqlite")
        let otherDB = try Database(path: other.path)
        try otherDB.script("CREATE TABLE notes(id INTEGER)")

        XCTAssertThrowsError(try world.app.backup.restore(from: other)) {
            XCTAssertEqual($0.localizedDescription, "This file is not a Flashcards backup")
        }
        XCTAssertEqual(try world.app.profiles.people().count, 1)
    }

    func testAFileThatIsNotSqliteAtAllIsRefused() throws {
        let world = try World()
        let junk = file("junk.sqlite")
        try Data("hello, this is not a database".utf8).write(to: junk)

        XCTAssertThrowsError(try world.app.backup.restore(from: junk)) {
            XCTAssertEqual($0 as? BackupError, .notABackup)
        }
    }

    func testAMissingFileIsReported() throws {
        let world = try World()

        XCTAssertThrowsError(try world.app.backup.restore(from: file("missing.sqlite"))) {
            guard case .unreadable = $0 as? BackupError else { return XCTFail("expected unreadable") }
        }
    }

    func testABackupFromANewerSchemaIsRefusedWithAClearMessage() throws {
        let world = try World()
        try world.person("Maya")
        let newer = file("newer.sqlite")
        let newerDB = try Database(path: newer.path)
        try Migrator.current.migrate(newerDB)
        try newerDB.setSchemaVersion(99)

        XCTAssertThrowsError(try world.app.backup.restore(from: newer)) {
            XCTAssertEqual($0.localizedDescription, "This backup is from a newer version of the app. Update the app first.")
        }
        XCTAssertEqual(try world.app.profiles.people().count, 1)
    }

    func testABackupFromAnOlderSchemaIsUpgradedAndLosesNothing() throws {
        let (source, _) = try populated()
        let oldFile = file("v1.sqlite")
        try source.app.backup.export(to: oldFile)
        let target = try World()
        let addNotes = MigrationStep(version: 3) { try $0.script("ALTER TABLE profile ADD COLUMN note TEXT") }
        let nextRelease = Migrator(steps: Migrator.current.steps + [addNotes])
        let backup = Backup(db: target.db, roles: target.roles, migrator: nextRelease, safetyFolder: nil, afterRestore: {})

        try backup.restore(from: oldFile)

        XCTAssertEqual(try target.db.schemaVersion(), 3)
        XCTAssertEqual(try target.db.count("SELECT COUNT(*) AS n FROM profile"), 3)
        XCTAssertEqual(try target.db.count("SELECT COUNT(*) AS n FROM answer"), 1)
    }

    func testRestoringWithoutASafetyFolderStillWorks() throws {
        let (source, _) = try populated()
        let backupFile = file("from-source.sqlite")
        try source.app.backup.export(to: backupFile)
        let target = try World()

        XCTAssertNil(try target.app.backup.restore(from: backupFile))
        XCTAssertEqual(try target.app.profiles.people().count, 2)
    }
}
