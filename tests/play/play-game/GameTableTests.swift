import XCTest
@testable import FlashcardsCore

final class GameTableTests: XCTestCase {
    private func world(
        whites: Int = 20,
        blacks: [String] = ["Coming soon! Batman vs. _____.", "Two _____."],
        shuffle: @escaping ([String]) -> [String] = { $0 }
    ) throws -> (World, Profile, Profile) {
        let world = try World(shuffle: shuffle)
        try world.app.loadGameCards([GameFixtures.data(whites: whites, blacks: blacks)])
        let maya = try world.person("Maya")
        let sam = try world.person("Sam")
        return (world, maya, sam)
    }

    func testTheLoadedCardSetsCanBeChosenAndInvalidCardDataIsRefused() throws {
        let (world, _, _) = try world()
        XCTAssertEqual(world.app.gameCards.sets.map(\.id), ["s"])

        XCTAssertThrowsError(try world.app.loadGameCards([Data("not json".utf8)])) {
            XCTAssertTrue($0.localizedDescription.hasPrefix("The card data could not be read"), $0.localizedDescription)
        }
    }

    func testStartingAGameWithTwoExistingPeopleUsesTheirProfiles() throws {
        let (world, maya, sam) = try world()

        let table = try world.app.startGame(personIDs: [maya.id, sam.id], sets: ["s"])

        XCTAssertEqual(table.game.players.map(\.name), ["Maya", "Sam"])
        XCTAssertEqual(table.game.phase, .passToPlayer(GamePlayer(profile: maya)))
    }

    func testStartingAGameWithIncludeMeAndOnePersonCreatesATwoPlayerGame() throws {
        let (world, maya, _) = try world()

        let table = try world.app.startGame(personIDs: [maya.id], includeMe: true, sets: ["s"])

        XCTAssertEqual(table.game.players.map(\.name), ["Me", "Maya"])
    }

    func testStartingAGameWithAGroupUsesItsMembersInSortedOrder() throws {
        let (world, maya, sam) = try world()
        let group = try world.app.groups.createGroup(name: "Weekend Crew", memberIDs: [sam.id, maya.id])

        let table = try world.app.startGame(groupID: group.id, sets: ["s"])

        XCTAssertEqual(table.game.players.map(\.name), ["Maya", "Sam"])
        XCTAssertEqual(table.game.targetGroupID, group.id)
    }

    func testCompletedRoundWithPeopleSavesEachPlayersOwnPickToTheirProfileHistory() throws {
        let (world, maya, sam) = try world()
        let table = try world.app.startGame(personIDs: [maya.id, sam.id], sets: ["s"])

        try table.ready()
        try table.submit(["s-w-1"])
        XCTAssertTrue(try world.app.gameHistory.history(profileID: maya.id).isEmpty, "nothing recorded before reveal")

        try table.ready()
        try table.submit(["s-w-2"])

        let mayaHistory = try world.app.gameHistory.history(profileID: maya.id)
        let samHistory = try world.app.gameHistory.history(profileID: sam.id)
        XCTAssertEqual(mayaHistory.map(\.prompt), ["Coming soon! Batman vs. _____."])
        XCTAssertEqual(mayaHistory.first?.answerLines(for: maya), ["White 1."])
        XCTAssertEqual(samHistory.first?.answerLines(for: sam), ["White 2."])
    }

    func testCompletedRoundWithAGroupSavesEveryonesNamedPickToTheGroupOnly() throws {
        let (world, maya, sam) = try world()
        let group = try world.app.groups.createGroup(name: "Weekend Crew", memberIDs: [maya.id, sam.id])
        let table = try world.app.startGame(groupID: group.id, sets: ["s"])

        try table.ready()
        try table.submit(["s-w-1"])
        try table.ready()
        try table.submit(["s-w-2"])

        let groupHistory = try world.app.gameHistory.history(profileID: group.id)
        XCTAssertEqual(groupHistory.map(\.prompt), ["Coming soon! Batman vs. _____."])
        XCTAssertEqual(groupHistory.first?.answerLines(for: group), ["Maya: White 1.", "Sam: White 2."])
        XCTAssertTrue(try world.app.gameHistory.history(profileID: maya.id).isEmpty)
        XCTAssertTrue(try world.app.gameHistory.history(profileID: sam.id).isEmpty)
    }

    func testAlreadyPlayedBlackCardsStayOutOfFutureGamesUntilResetWhichKeepsSavedHistory() throws {
        let (world, maya, sam) = try world(blacks: ["One _____.", "Two _____."])
        let first = try world.app.startGame(personIDs: [maya.id, sam.id], sets: ["s"])
        XCTAssertEqual(first.game.blackCard.text, "One _____.")
        try first.ready()
        try first.submit(["s-w-1"])
        try first.ready()
        try first.submit(["s-w-2"])
        try first.end()

        let second = try world.app.startGame(personIDs: [maya.id, sam.id], sets: ["s"])
        XCTAssertEqual(second.game.blackCard.text, "Two _____.")
        try second.ready()
        try second.submit(["s-w-1"])
        try second.ready()
        try second.submit(["s-w-2"])
        try second.nextRound()
        XCTAssertEqual(second.game.phase, .allAsked)

        try second.resetAndContinue()

        XCTAssertEqual(second.game.blackCard.text, "One _____.")
        XCTAssertEqual(try world.app.gameHistory.history(profileID: maya.id).count, 2, "saved history is kept")
    }

    func testAGameInProgressSurvivesRestartAndEndingClearsItWithoutDuplicatingHistory() throws {
        let (world, maya, sam) = try world()
        let table = try world.app.startGame(personIDs: [maya.id, sam.id], sets: ["s"])
        try table.ready()
        try table.submit(["s-w-1"])

        let resumed = try XCTUnwrap(try world.app.resumeGame())
        XCTAssertEqual(resumed.game, table.game)
        XCTAssertEqual(resumed.game.phase, .passToPlayer(GamePlayer(profile: sam)))

        try resumed.ready()
        try resumed.submit(["s-w-2"])
        let resumedAtReveal = try XCTUnwrap(try world.app.resumeGame())
        try resumedAtReveal.nextRound()
        XCTAssertEqual(try world.app.gameHistory.history(profileID: maya.id).count, 1)

        try resumedAtReveal.end()
        XCTAssertNil(try world.app.resumeGame())
    }

    func testARefusedMoveChangesNothingAndCorruptSavedGameIsDroppedCleanly() throws {
        let (world, maya, sam) = try world()
        let table = try world.app.startGame(personIDs: [maya.id, sam.id], sets: ["s"])
        try table.ready()
        let before = table.game

        XCTAssertThrowsError(try table.submit(["s-w-99"]))
        XCTAssertEqual(table.game, before)

        try world.db.setSetting("game.current", "{ broken")
        XCTAssertNil(try world.app.resumeGame())
        XCTAssertNil(try world.db.setting("game.current"))
    }

    func testLastGameSetupIsRememberedAcrossEndAndBackupRestoresGameHistory() throws {
        let (world, maya, sam) = try world()
        XCTAssertNil(try world.app.lastGameSetup())
        let table = try world.app.startGame(personIDs: [maya.id, sam.id], includeMe: true, sets: ["s"])
        try table.ready()
        try table.submit(["s-w-1"])
        try table.ready()
        try table.submit(["s-w-1"])
        try table.ready()
        try table.submit(["s-w-2"])
        try table.end()

        XCTAssertEqual(
            try world.app.lastGameSetup(),
            SavedGameSetup(groupID: nil, personIDs: [maya.id, sam.id], includeMe: true, sets: ["s"]))

        let url = FileManager.default.temporaryDirectory.appendingPathComponent("game-backup-\(UUID().uuidString).sqlite")
        defer { try? FileManager.default.removeItem(at: url) }
        try world.app.backup.export(to: url)

        let restored = try World()
        try restored.app.backup.restore(from: url)
        XCTAssertEqual(try restored.app.gameHistory.history(profileID: maya.id).count, 1)
    }
}
