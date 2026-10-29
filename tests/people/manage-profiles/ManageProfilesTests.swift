import XCTest
@testable import FlashcardsCore

final class ManageProfilesTests: XCTestCase {
    func testAddingAPersonPutsThemInThePeopleListAndSelectsThem() throws {
        let world = try World()

        let maya = try world.app.profiles.addPerson(name: "Maya", emoji: "🌸")

        XCTAssertEqual(try world.app.profiles.people().map(\.profile), [maya])
        XCTAssertEqual(maya.emoji, "🌸")
        XCTAssertEqual(try world.app.profiles.selectedProfile(), maya)
    }

    func testAPersonNameIsTrimmedBeforeItIsSaved() throws {
        let world = try World()

        let maya = try world.app.profiles.addPerson(name: "  Maya  ")

        XCTAssertEqual(maya.name, "Maya")
    }

    func testANameIsRequired() throws {
        let world = try World()

        XCTAssertThrowsError(try world.app.profiles.addPerson(name: "   ")) { error in
            XCTAssertEqual(error as? ProfileError, .emptyName)
            XCTAssertEqual(error.localizedDescription, "Enter a name")
        }
        XCTAssertEqual(try world.app.profiles.people(), [])
    }

    func testDuplicateNamesAreRefusedIgnoringCase() throws {
        let world = try World()
        try world.person("Maya")

        XCTAssertThrowsError(try world.app.profiles.addPerson(name: "maya")) { error in
            XCTAssertEqual(error.localizedDescription, "A profile named Maya already exists")
        }
        XCTAssertEqual(try world.app.profiles.people().count, 1)
    }

    func testRenamingKeepsTheHistory() throws {
        let world = try World()
        let maya = try world.person("Maya")
        try world.deck("Deep Talk", cards: ["Q1", "Q2", "Q3", "Q4", "Q5"])
        try world.markAsked(["Q1", "Q2", "Q3", "Q4", "Q5"], for: maya)

        try world.app.profiles.rename(maya.id, to: "Maya R.")

        let renamed = try XCTUnwrap(try world.app.profiles.people().first)
        XCTAssertEqual(renamed.profile.name, "Maya R.")
        XCTAssertEqual(renamed.progress.asked, 5)
    }

    func testRenamingToAnotherProfilesNameIsRefused() throws {
        let world = try World()
        let maya = try world.person("Maya")
        try world.person("Sam")

        XCTAssertThrowsError(try world.app.profiles.rename(maya.id, to: "sam"))
    }

    func testRenamingToTheSameNameWithDifferentCaseIsAllowed() throws {
        let world = try World()
        let maya = try world.person("Maya")

        try world.app.profiles.rename(maya.id, to: "MAYA")

        XCTAssertEqual(try world.app.profiles.profile(maya.id)?.name, "MAYA")
    }

    func testDeletingReportsWhatWillBeLostThenRemovesTheProfileAndItsHistory() throws {
        let world = try World()
        let maya = try world.person("Maya")
        try world.deck("Deep Talk", cards: ["Q1", "Q2", "Q3", "Q4", "Q5"])
        try world.markAsked(["Q1", "Q2", "Q3", "Q4", "Q5"], for: maya)
        try world.saveAnswerDirectly("Lisbon", card: "Q1", for: maya)

        XCTAssertEqual(try world.app.profiles.impactOfDeleting(maya.id), DeletionImpact(asked: 5, answers: 1))
        try world.app.profiles.delete(maya.id)

        XCTAssertEqual(try world.app.profiles.people(), [])
        XCTAssertEqual(try world.db.count("SELECT COUNT(*) AS n FROM card_state"), 0)
        XCTAssertEqual(try world.db.count("SELECT COUNT(*) AS n FROM answer"), 0)
    }

    func testDeletingTheSelectedProfileSelectsAnotherOne() throws {
        let world = try World()
        let maya = try world.person("Maya")
        let sam = try world.person("Sam")
        try world.app.profiles.select(maya.id)

        try world.app.profiles.delete(maya.id)

        XCTAssertEqual(try world.app.profiles.selectedProfile(), sam)
    }

    func testTheLastUsedProfileIsSelectedOnRelaunch() throws {
        let world = try World()
        try world.person("Maya")
        let sam = try world.person("Sam")
        try world.app.profiles.select(sam.id)

        let relaunched = try world.relaunch()

        XCTAssertEqual(try relaunched.profiles.selectedProfile(), sam)
    }

    func testFirstLaunchHasNoProfileSelected() throws {
        let world = try World()

        XCTAssertNil(try world.app.profiles.selectedProfile())
        XCTAssertEqual(try world.app.profiles.people(), [])
    }

    func testPeopleListShowsProgressAndAnswerCounts() throws {
        let world = try World()
        let maya = try world.person("Maya")
        try world.deck("Deep Talk", cards: ["Q1", "Q2", "Q3"])
        try world.markAsked(["Q1", "Q2"], for: maya)
        try world.saveAnswerDirectly("Lisbon", card: "Q1", for: maya)

        let summary = try XCTUnwrap(try world.app.profiles.people().first)

        XCTAssertEqual(summary.progress, Progress(asked: 2, total: 3))
        XCTAssertEqual(summary.answerCount, 1)
    }
}
