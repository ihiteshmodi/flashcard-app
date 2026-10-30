import XCTest
@testable import FlashcardsCore

final class TagPeopleTests: XCTestCase {
    func testAPersonShowsGenderAndClosenessOnTheProfilesList() throws {
        let world = try World()

        let maya = try world.person("Maya", gender: .woman, .friend)

        XCTAssertEqual(maya.tagSummary, "Woman · Friend")
        XCTAssertEqual(try world.app.profiles.profile(maya.id)?.tagSummary, "Woman · Friend")
    }

    func testClosenessDefaultsToFriendAndGenderToNotSet() throws {
        let world = try World()

        let sam = try world.person("Sam")

        XCTAssertNil(sam.gender)
        XCTAssertEqual(sam.closeness, .friend)
        XCTAssertNil(sam.tagSummary)
    }

    func testMovingThroughTheRelationshipKeepsAskedCardsAndAnswers() throws {
        let moves: [(Closeness, Closeness)] = [(.friend, .dating), (.dating, .partner), (.partner, .dating), (.dating, .friend)]
        for (from, to) in moves {
            let world = try World()
            try world.deck("Deep Talk", cards: ["Q1", "Q2"])
            let maya = try world.person("Maya", gender: .woman, from)
            try world.markAsked(["Q1"], for: maya)
            try world.saveAnswerDirectly("Blue", card: "Q1", for: maya)

            try world.app.setCloseness(of: maya.id, to: to)

            XCTAssertEqual(try world.app.profiles.profile(maya.id)?.tagSummary, "Woman · \(to.title)")
            XCTAssertEqual(try world.app.answers.answer(profileID: maya.id, cardID: try world.card("Q1").id)?.text, "Blue")
            XCTAssertEqual(try world.app.session(for: maya.id).progress, Progress(asked: 1, total: 2))
        }
    }

    func testANewClosenessUnlocksCardsInTheOpenStack() throws {
        let world = try World()
        try world.deck("Mixed", cards: ["Plain", "Spicy"])
        try world.label("Spicy", .women, .flirty)
        let maya = try world.person("Maya", gender: .woman, .friend)
        XCTAssertEqual(try world.stack(for: maya), ["Plain"])

        try world.app.setCloseness(of: maya.id, to: .dating)

        XCTAssertEqual(try world.stack(for: maya), ["Plain", "Spicy"])
    }

    func testGenderCanBeSetLaterAndUnlocksSafeWomenCards() throws {
        let world = try World()
        try world.deck("Mixed", cards: ["Plain", "For women"])
        try world.label("For women", .women)
        let maya = try world.person("Maya")
        XCTAssertEqual(try world.stack(for: maya), ["Plain"])

        try world.app.setGender(of: maya.id, to: .woman)

        XCTAssertEqual(try world.stack(for: maya), ["Plain", "For women"])
    }

    func testOnlyWomanAndManAreOffered() {
        XCTAssertEqual(Gender.allCases.map(\.title), ["Woman", "Man"])
        XCTAssertEqual(Closeness.allCases.map(\.title), ["Friend", "Dating", "Partner"])
    }

    func testGroupsHaveNoGenderOrClosenessEvenWhenSet() throws {
        let world = try World()
        let maya = try world.person("Maya")
        let group = try world.app.groups.createGroup(name: "Game Night", memberIDs: [maya.id])

        try world.app.setGender(of: group.id, to: .woman)
        try world.app.setCloseness(of: group.id, to: .partner)

        let stored = try XCTUnwrap(try world.app.profiles.profile(group.id))
        XCTAssertNil(stored.gender)
        XCTAssertEqual(stored.closeness, .friend)
        XCTAssertNil(stored.tagSummary)
    }

    func testIAmIsKeptAndCanBeCleared() throws {
        let world = try World()
        XCTAssertNil(try world.app.owner.gender())

        try world.app.setOwnerGender(.man)
        XCTAssertEqual(try world.app.owner.gender(), .man)

        try world.app.setOwnerGender(nil)
        XCTAssertNil(try world.app.owner.gender())
    }

    func testTagsAndIAmSurviveAnExportAndImport() throws {
        let source = try World()
        try source.person("Maya", gender: .woman, .partner)
        try source.app.setOwnerGender(.man)
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("tags-\(UUID().uuidString).sqlite")
        defer { try? FileManager.default.removeItem(at: file) }
        try source.app.backup.export(to: file)
        let target = try World()

        _ = try target.app.backup.restore(from: file)

        let maya = try XCTUnwrap(try target.app.profiles.people().first)
        XCTAssertEqual(maya.profile.tagSummary, "Woman · Partner")
        XCTAssertEqual(try target.app.owner.gender(), .man)
    }

    func testABackupFromBeforeTagsExistedMakesEveryoneUntagged() throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("v1-\(UUID().uuidString).sqlite")
        defer { try? FileManager.default.removeItem(at: file) }
        let old = try Database(path: file.path)
        try Migrator(steps: [Migrator.current.steps[0]]).migrate(old)
        try old.run("INSERT INTO profile(id, kind, name, emoji, name_key, created_at) VALUES('p1', 'person', 'Maya', 'x', 'maya', 0)")
        let target = try World()

        _ = try target.app.backup.restore(from: file)

        let maya = try XCTUnwrap(try target.app.profiles.people().first)
        XCTAssertNil(maya.profile.gender)
        XCTAssertEqual(maya.profile.closeness, .friend)
    }
}
