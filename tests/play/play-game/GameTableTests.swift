import XCTest
@testable import FlashcardsCore

final class GameTableTests: XCTestCase {
    private func world(whites: Int = 60) throws -> World {
        let world = try World()
        try world.app.loadGameCards([GameFixtures.data(whites: whites)])
        return world
    }

    private func table(_ world: World) throws -> GameTable {
        try world.app.startGame(players: ["Maya", "Sam", "Lee"], sets: ["s"])
    }

    func testTheLoadedCardSetsCanBeChosenForAGame() throws {
        XCTAssertEqual(try world().app.gameCards.sets.map(\.id), ["s"])
    }

    func testACardFileThatCannotBeReadIsRefusedWithTheReason() throws {
        let world = try World()

        XCTAssertThrowsError(try world.app.loadGameCards([Data("not json".utf8)])) {
            XCTAssertTrue($0.localizedDescription.hasPrefix("The card data could not be read"), $0.localizedDescription)
        }
    }

    func testAGameStartsFromTheLoadedCards() throws {
        let table = try table(try world())

        XCTAssertEqual(table.game.phase, .passToPlayer("Sam"))
        XCTAssertEqual(table.game.players, ["Maya", "Sam", "Lee"])
    }

    func testAGameNeedsEnoughLoadedCards() throws {
        let world = try world(whites: 20)

        XCTAssertThrowsError(try table(world)) {
            XCTAssertEqual($0.localizedDescription, "These sets do not have enough white cards for 3 players")
        }
    }

    func testAGameInTheMiddleOfARoundIsFoundAgainWithTheSameHandsScoresAndBlackCard() throws {
        let world = try world()
        let table = try table(world)
        try table.ready()
        try table.play(["s-w-11"])

        let resumed = try XCTUnwrap(try world.app.resumeGame())

        XCTAssertEqual(resumed.game, table.game)
        XCTAssertEqual(resumed.game.phase, .passToPlayer("Lee"))
    }

    func testEveryMoveIsKeptSoTheLastOneIsNeverLost() throws {
        let world = try world()
        let table = try table(world)
        try table.ready()
        try table.play(["s-w-11"])
        try table.ready()
        try table.play(["s-w-21"])
        try table.ready()
        try table.choose(playAt: 0)
        try table.nextRound()

        let resumed = try XCTUnwrap(try world.app.resumeGame())

        XCTAssertEqual(resumed.game.round, 2)
        XCTAssertEqual(resumed.game.scoreboard.map(\.points), [0, 1, 0])
    }

    func testARefusedMoveChangesNothingAndKeepsTheSavedGame() throws {
        let world = try world()
        let table = try table(world)
        try table.ready()
        let before = table.game

        XCTAssertThrowsError(try table.play(["s-w-1"]))

        XCTAssertEqual(table.game, before)
        XCTAssertEqual(try world.app.resumeGame()?.game, before)
    }

    func testThereIsNoGameToContinueBeforeOneIsStarted() throws {
        XCTAssertNil(try world().app.resumeGame())
    }

    func testEndingTheGameGivesTheFinalScoresAndForgetsIt() throws {
        let world = try world()
        let table = try table(world)

        let finalScores = try table.end()

        XCTAssertEqual(finalScores.map(\.name), ["Maya", "Sam", "Lee"])
        XCTAssertNil(try world.app.resumeGame())
    }

    func testStartingANewGameReplacesTheOneInProgress() throws {
        let world = try world()
        _ = try table(world)

        _ = try world.app.startGame(players: ["Ann", "Bo", "Cy", "Di"], sets: ["s"])

        XCTAssertEqual(try world.app.resumeGame()?.game.players, ["Ann", "Bo", "Cy", "Di"])
    }

    func testASavedGameThatCannotBeReadIsDroppedInsteadOfBlockingTheGame() throws {
        let world = try world()
        _ = try table(world)
        try world.db.setSetting("game.current", "{ broken")

        XCTAssertNil(try world.app.resumeGame())
        XCTAssertNil(try world.db.setting("game.current"))
    }

    func testTheNextRoundMakesTheWhitePileAgainWithTheAppsShuffle() throws {
        let world = try World(shuffle: { Array($0.reversed()) })
        try world.app.loadGameCards([GameFixtures.data(whites: 30)])
        let table = try table(world)
        try table.ready()
        try table.play([table.game.visibleHand[0].id])
        try table.ready()
        try table.play([table.game.visibleHand[0].id])
        try table.ready()
        try table.choose(playAt: 0)

        try table.nextRound()

        // The reversed deck gave Sam s-w-20 and Lee s-w-10 to play; the pile made again from those two is reversed.
        XCTAssertTrue(table.game.visibleHandOf("Sam").map(\.id).contains("s-w-10"))
    }

    func testNothingIsRememberedBeforeTheFirstGame() throws {
        XCTAssertNil(try world().app.lastGameSetup())
    }

    func testTheLastPlayersAndSetsAreRememberedForTheNextGame() throws {
        let world = try world()
        _ = try world.app.startGame(players: [" Maya", "Sam", "Lee"], sets: ["s"])

        let setup = try XCTUnwrap(try world.app.lastGameSetup())

        XCTAssertEqual(setup.players, ["Maya", "Sam", "Lee"])
        XCTAssertEqual(setup.sets, ["s"])
    }

    func testAGameThatCouldNotStartIsNotRemembered() throws {
        let world = try world()

        XCTAssertThrowsError(try world.app.startGame(players: ["Maya"], sets: ["s"]))

        XCTAssertNil(try world.app.lastGameSetup())
    }

    func testTheRememberedSetupSurvivesTheGameEnding() throws {
        let world = try world()
        let table = try table(world)

        _ = try table.end()

        XCTAssertEqual(try world.app.lastGameSetup()?.players, ["Maya", "Sam", "Lee"])
    }
}
