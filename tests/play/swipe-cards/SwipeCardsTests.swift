import XCTest
@testable import FlashcardsCore

final class SwipeCardsTests: XCTestCase {
    private func world(shuffle: @escaping ([String]) -> [String] = { $0 }) throws -> (World, Profile, Profile) {
        let world = try World(shuffle: shuffle)
        try world.deck("Deep Talk", cards: ["Q1", "Q2", "Q3"])
        let maya = try world.person("Maya")
        let sam = try world.person("Sam")
        return (world, maya, sam)
    }

    private func prompts(_ session: CardSession) -> [String] { session.stack.map(\.prompt) }

    func testANewProfileSeesEveryCardInTheShuffledOrder() throws {
        let (world, maya, _) = try world(shuffle: { $0.reversed() })

        let session = try world.app.session(for: maya.id)

        XCTAssertEqual(prompts(session), ["Q3", "Q2", "Q1"])
        XCTAssertEqual(session.progress, Progress(asked: 0, total: 3))
    }

    func testSwipingRightMarksTheCardAskedForThisProfileOnly() throws {
        let (world, maya, sam) = try world()
        let session = try world.app.session(for: maya.id)

        let asked = try session.swipeRight()

        XCTAssertEqual(asked?.prompt, "Q1")
        XCTAssertEqual(session.topCard?.prompt, "Q2")
        XCTAssertEqual(session.progress.asked, 1)
        XCTAssertEqual(prompts(try world.app.session(for: sam.id)), ["Q1", "Q2", "Q3"])
    }

    func testAnAskedCardNeverComesBackForTheSameProfile() throws {
        let (world, maya, _) = try world()
        try world.app.session(for: maya.id).swipeRight()

        let reopened = try CardSession(profileID: maya.id, db: world.db, roles: world.roles)

        XCTAssertEqual(prompts(reopened), ["Q2", "Q3"])
    }

    func testSwipingLeftSkipsTheCardToTheEndAndLeavesItUnasked() throws {
        let (world, maya, _) = try world()
        let session = try world.app.session(for: maya.id)

        try session.swipeLeft()

        XCTAssertEqual(prompts(session), ["Q2", "Q3", "Q1"])
        XCTAssertEqual(session.progress.asked, 0)
    }

    func testSkippedCardsComeAfterUnseenOnesWhenTheStackIsRebuilt() throws {
        let (world, maya, _) = try world()
        let session = try world.app.session(for: maya.id)
        try session.swipeLeft()

        let reopened = try CardSession(profileID: maya.id, db: world.db, roles: world.roles)

        XCTAssertEqual(prompts(reopened), ["Q2", "Q3", "Q1"])
    }

    func testOnlySkippedCardsLeftStillShowThem() throws {
        let (world, maya, _) = try world()
        try world.markAsked(["Q1", "Q2"], for: maya)
        let session = try world.app.session(for: maya.id)
        try session.swipeLeft()

        XCTAssertEqual(prompts(session), ["Q3"])
        XCTAssertFalse(session.isAllAsked)
    }

    func testSwitchingProfileChangesTheStack() throws {
        let (world, maya, sam) = try world()
        try world.markAsked(["Q1", "Q2"], for: maya)

        XCTAssertEqual(prompts(try world.app.session(for: maya.id)), ["Q3"])
        XCTAssertEqual(prompts(try world.app.session(for: sam.id)), ["Q1", "Q2", "Q3"])
    }

    func testTheSameSessionIsReusedSoUndoHistorySurvivesASwitch() throws {
        let (world, maya, sam) = try world()
        try world.app.session(for: maya.id).swipeRight()
        _ = try world.app.session(for: sam.id)

        XCTAssertTrue(try world.app.session(for: maya.id).canUndo)
    }

    func testTurnedOffDecksAreLeftOutOfTheStack() throws {
        let (world, maya, _) = try world()
        try world.deck("Dares", cards: ["D1"], kind: .dare)
        try world.app.decks.setDeck("dares", on: false, for: maya.id)

        XCTAssertEqual(prompts(try world.app.session(for: maya.id)), ["Q1", "Q2", "Q3"])
    }

    func testSyncPicksUpDeckChangesAndNewCardsWithoutReshuffling() throws {
        let (world, maya, _) = try world()
        let session = try world.app.session(for: maya.id)
        try session.swipeRight()
        try world.deck("Dares", cards: ["D1"], kind: .dare)

        try session.syncWithLibrary()
        XCTAssertEqual(prompts(session), ["Q2", "Q3", "D1"])
        try world.app.decks.setDeck("dares", on: false, for: maya.id)
        try session.syncWithLibrary()

        XCTAssertEqual(prompts(session), ["Q2", "Q3"])
        XCTAssertTrue(session.canUndo)
    }

    func testUndoReversesTheLastSwipe() throws {
        let (world, maya, _) = try world()
        let session = try world.app.session(for: maya.id)
        try session.swipeRight()

        try session.undo()

        XCTAssertEqual(session.topCard?.prompt, "Q1")
        XCTAssertEqual(try CardStates.status(world.db, profileID: maya.id, cardID: "deep-talk-1"), nil)
        XCTAssertEqual(session.progress.asked, 0)
    }

    func testUndoKeepsTheSavedAnswer() throws {
        let (world, maya, _) = try world()
        let session = try world.app.session(for: maya.id)
        try session.swipeRight()
        try world.saveAnswerDirectly("Lisbon", card: "Q1", for: maya)

        try session.undo()

        XCTAssertEqual(try world.db.count("SELECT COUNT(*) AS n FROM answer"), 1)
    }

    func testUndoOfASkipPutsTheCardBackOnTop() throws {
        let (world, maya, _) = try world()
        let session = try world.app.session(for: maya.id)
        try session.swipeLeft()

        try session.undo()

        XCTAssertEqual(prompts(session), ["Q1", "Q2", "Q3"])
        XCTAssertEqual(try CardStates.status(world.db, profileID: maya.id, cardID: "deep-talk-1"), nil)
    }

    func testUndoOfAnAskedCardThatWasSkippedBeforeRestoresTheSkip() throws {
        let (world, maya, _) = try world()
        let session = try world.app.session(for: maya.id)
        try session.swipeLeft()
        try session.swipeLeft()
        try session.swipeLeft()
        try session.swipeRight()

        try session.undo()

        XCTAssertEqual(try CardStates.status(world.db, profileID: maya.id, cardID: "deep-talk-1"), .skipped)
    }

    func testRedoReappliesAnUndoneSwipe() throws {
        let (world, maya, _) = try world()
        let session = try world.app.session(for: maya.id)
        try session.swipeRight()
        try session.undo()

        try session.redo()

        XCTAssertEqual(try CardStates.status(world.db, profileID: maya.id, cardID: "deep-talk-1"), .asked)
        XCTAssertEqual(session.topCard?.prompt, "Q2")
        XCTAssertFalse(session.canRedo)
    }

    func testRedoAlsoRestoresASkip() throws {
        let (world, maya, _) = try world()
        let session = try world.app.session(for: maya.id)
        try session.swipeLeft()
        try session.undo()

        try session.redo()

        XCTAssertEqual(prompts(session), ["Q2", "Q3", "Q1"])
    }

    func testANewSwipeClearsRedo() throws {
        let (world, maya, _) = try world()
        let session = try world.app.session(for: maya.id)
        try session.swipeRight()
        try session.undo()

        try session.swipeRight()

        XCTAssertFalse(session.canRedo)
    }

    func testUndoAndRedoWithNothingToDoChangeNothing() throws {
        let (world, maya, _) = try world()
        let session = try world.app.session(for: maya.id)

        try session.undo()
        try session.redo()

        XCTAssertFalse(session.canUndo)
        XCTAssertFalse(session.canRedo)
        XCTAssertEqual(prompts(session), ["Q1", "Q2", "Q3"])
    }

    func testUndoCanStepBackThroughSeveralSwipes() throws {
        let (world, maya, _) = try world()
        let session = try world.app.session(for: maya.id)
        try session.swipeRight()
        try session.swipeRight()

        try session.undo()
        try session.undo()

        XCTAssertEqual(prompts(session), ["Q1", "Q2", "Q3"])
        XCTAssertFalse(session.canUndo)
    }

    func testSwipingWithAnEmptyStackDoesNothing() throws {
        let (world, maya, _) = try world()
        try world.markAsked(["Q1", "Q2", "Q3"], for: maya)
        let session = try world.app.session(for: maya.id)

        XCTAssertNil(try session.swipeRight())
        XCTAssertNoThrow(try session.swipeLeft())
    }

    func testWhenEverythingIsAskedTheSessionSaysSo() throws {
        let (world, maya, _) = try world()
        try world.markAsked(["Q1", "Q2", "Q3"], for: maya)

        let session = try world.app.session(for: maya.id)

        XCTAssertTrue(session.isAllAsked)
        XCTAssertEqual(session.stack, [])
    }

    func testStartOverBringsBackEveryCard() throws {
        let (world, maya, _) = try world()
        try world.markAsked(["Q1", "Q2", "Q3"], for: maya)
        let session = try world.app.session(for: maya.id)

        try session.startOver()

        XCTAssertEqual(prompts(session), ["Q1", "Q2", "Q3"])
        XCTAssertFalse(session.isAllAsked)
        XCTAssertFalse(session.canUndo)
    }

    func testStartOverKeepsSavedAnswers() throws {
        let (world, maya, _) = try world()
        try world.markAsked(["Q1"], for: maya)
        try world.saveAnswerDirectly("Lisbon", card: "Q1", for: maya)

        try world.app.session(for: maya.id).startOver()

        XCTAssertEqual(try world.db.count("SELECT COUNT(*) AS n FROM answer"), 1)
    }

    func testStartOverForOnePersonLeavesAnotherUntouched() throws {
        let (world, maya, sam) = try world()
        try world.markAsked(["Q1"], for: maya)
        try world.markAsked(["Q1"], for: sam)

        try world.app.session(for: maya.id).startOver()

        XCTAssertEqual(prompts(try world.app.session(for: sam.id)), ["Q2", "Q3"])
    }

    func testAnEmptyLibraryReportsNoCards() throws {
        let world = try World()
        let maya = try world.person("Maya")

        XCTAssertTrue(try world.app.session(for: maya.id).hasNoCards)
    }
}
