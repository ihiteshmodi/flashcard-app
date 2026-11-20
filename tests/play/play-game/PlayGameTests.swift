import XCTest
@testable import FlashcardsCore

final class PlayGameTests: XCTestCase {
    private let identity: ([String]) -> [String] = { $0 }
    private let reversed: ([String]) -> [String] = { Array($0.reversed()) }

    private func start(
        _ players: [GamePlayer] = GameFixtures.players("Maya", "Sam"),
        whites: Int = 20,
        blacks: [String] = GameFixtures.blacks,
        sets: Set<String> = ["s"],
        excludedBlackIDs: Set<String> = [],
        optionCount: Int = 12,
        shuffle: ([String]) -> [String] = { $0 }
    ) throws -> Game {
        try Game.start(
            players: players,
            library: try GameFixtures.library(whites: whites, blacks: blacks),
            sets: sets,
            excludedBlackIDs: excludedBlackIDs,
            optionCount: optionCount,
            shuffle: shuffle)
    }

    private func message(_ error: Error) -> String { error.localizedDescription }

    // MARK: Starting and player counts

    func testATwoPlayerGameTurnsABlackCardAndPreparesTwelveSharedWhiteOptions() throws {
        let game = try start()

        XCTAssertEqual(game.blackCard.id, "s-b-1")
        XCTAssertEqual(game.round, 1)
        XCTAssertEqual(game.phase, .passToPlayer(GameFixtures.players("Maya")[0]))
        XCTAssertEqual(game.visibleOptions, [])
    }

    func testIncludingMeAlongsideOneFriendStartsATwoPlayerGame() throws {
        let maya = GameFixtures.players("Maya")[0]
        let game = try start([.me, maya])

        XCTAssertEqual(game.players.map(\.name), ["Me", "Maya"])
        XCTAssertEqual(game.phase, .passToPlayer(.me))
    }

    func testASinglePlayerIsAllowedWithNoThreePlayerMinimum() throws {
        let game = try start(GameFixtures.players("Maya"))

        XCTAssertEqual(game.players.map(\.name), ["Maya"])
    }

    func testAGameValidatesPlayersAndSets() throws {
        let eleven = (1...11).map { GamePlayer(id: "p-\($0)", name: "P\($0)", emoji: "🙂", profileID: "p-\($0)") }
        let duplicateName = [
            GamePlayer(id: "p-1", name: "Maya", emoji: "🙂", profileID: "p-1"),
            GamePlayer(id: "p-2", name: "maya", emoji: "🙂", profileID: "p-2"),
        ]
        let blankName = [GamePlayer(id: "p-1", name: "   ", emoji: "🙂", profileID: "p-1")]
        let cases: [(String, [GamePlayer], Set<String>, String)] = [
            ("no players", [], ["s"], "Pick at least one player"),
            ("eleven players", eleven, ["s"], "A game takes at most 10 players"),
            ("same name in another case", duplicateName, ["s"], "Each player needs a different name"),
            ("blank name", blankName, ["s"], "Every player needs a name"),
            ("no set switched on", GameFixtures.players("Maya", "Sam"), [], "Switch on at least one card set"),
        ]
        for (label, players, sets, expected) in cases {
            XCTAssertThrowsError(try start(players, sets: sets), label) {
                XCTAssertEqual(self.message($0), expected, label)
            }
        }
    }

    func testTheChosenSetsMustHoldAtLeastOneBlackCardAndEnoughWhiteCards() throws {
        XCTAssertThrowsError(try start(blacks: [])) {
            XCTAssertEqual(self.message($0), "These sets have no black cards")
        }
        XCTAssertThrowsError(try start(whites: 1, blacks: ["_____ and _____."])) {
            XCTAssertEqual(self.message($0), "These sets do not have enough white cards")
        }
    }

    // MARK: Shared reusable options and hidden turns

    func testEveryPlayerSeesTheExactSameWhiteOptionsAndCanPickTheExactSameAnswer() throws {
        var game = try start()

        try game.ready()
        let mayaOptions = game.visibleOptions
        XCTAssertEqual(mayaOptions.map(\.id), (1...12).map { "s-w-\($0)" })
        try game.submit(["s-w-1"])

        XCTAssertEqual(game.phase, .passToPlayer(GameFixtures.players("Sam")[0]))
        XCTAssertEqual(game.visibleOptions, [])
        XCTAssertEqual(game.revealedAnswers, [])

        try game.ready()
        XCTAssertEqual(game.visibleOptions, mayaOptions)
        XCTAssertEqual(game.revealedAnswers, [])
        XCTAssertNoThrow(try game.submit(["s-w-1"]))
    }

    func testChoicesStayHiddenUntilTheLastPlayerAnswersThenRevealShowsEveryPlayerWithTheirPick() throws {
        var game = try start(blacks: ["Coming soon! Batman vs. _____."])

        try game.ready()
        try game.submit(["s-w-1"])
        XCTAssertEqual(game.revealedAnswers, [])

        try game.ready()
        try game.submit(["s-w-2"])

        XCTAssertEqual(game.visibleOptions, [])
        XCTAssertEqual(game.revealedAnswers.map(\.player.name), ["Maya", "Sam"])
        XCTAssertEqual(game.revealedAnswers.map { $0.cards.map(\.text) }, [["White 1."], ["White 2."]])
    }

    // MARK: Multi-pick rules

    func testAMultiBlankBlackCardRequiresThatManyDistinctCardsFromTheOptionsInOrder() throws {
        var game = try start(blacks: ["_____ is a slippery slope that leads to _____."])
        try game.ready()

        XCTAssertThrowsError(try game.submit(["s-w-1"])) {
            XCTAssertEqual(self.message($0), "Choose 2 cards")
        }
        XCTAssertThrowsError(try game.submit(["s-w-1", "s-w-1"])) {
            XCTAssertEqual(self.message($0), "Choose different cards")
        }
        XCTAssertThrowsError(try game.submit(["s-w-1", "s-w-99"])) {
            XCTAssertEqual(self.message($0), "That card is not in the options")
        }

        try game.submit(["s-w-5", "s-w-2"])
        try game.ready()
        try game.submit(["s-w-3", "s-w-1"])

        XCTAssertEqual(game.revealedAnswers[0].cards.map(\.id), ["s-w-5", "s-w-2"])
        XCTAssertEqual(game.revealedAnswers[1].cards.map(\.id), ["s-w-3", "s-w-1"])
    }

    func testARefusedSubmissionChangesNothing() throws {
        var game = try start()
        try game.ready()
        let before = game

        _ = try? game.submit(["s-w-99"])

        XCTAssertEqual(game, before)
    }

    // MARK: Reusable white cards across rounds and unasked black cards

    func testWhiteCardsRemainAvailableInLaterRoundsEvenWithASmallSet() throws {
        var game = try start(whites: 5, optionCount: 12, shuffle: reversed)
        try game.ready()
        try game.submit(["s-w-5"])
        try game.ready()
        try game.submit(["s-w-4"])

        try game.nextRound(shuffle: identity)
        try game.ready()

        XCTAssertEqual(game.round, 2)
        XCTAssertEqual(game.visibleOptions.count, 5)
        XCTAssertTrue(game.visibleOptions.map(\.id).contains("s-w-5"))
    }

    func testAlreadyPlayedBlackCardsAreSkippedAndAllAskedAppearsWhenNoneRemainUntilReset() throws {
        let library = try GameFixtures.library(whites: 10, blacks: ["One _____.", "Two _____."])
        var game = try Game.start(
            players: GameFixtures.players("Maya", "Sam"),
            library: library,
            sets: ["s"],
            excludedBlackIDs: ["s-b-1"],
            shuffle: identity)

        XCTAssertEqual(game.blackCard.text, "Two _____.")

        try game.ready()
        try game.submit(["s-w-1"])
        try game.ready()
        try game.submit(["s-w-2"])
        try game.nextRound(shuffle: identity)

        XCTAssertEqual(game.phase, .allAsked)

        try game.resetAndContinue(library: library, shuffle: identity)
        XCTAssertEqual(game.blackCard.text, "One _____.")
        XCTAssertEqual(game.phase, .passToPlayer(GameFixtures.players("Maya")[0]))
    }

    func testStartingWhenEveryBlackCardWasAlreadyPlayedOpensInAllAsked() throws {
        let game = try start(blacks: ["One _____."], excludedBlackIDs: ["s-b-1"])

        XCTAssertEqual(game.phase, .allAsked)
    }

    // MARK: Out-of-turn guards & persistence

    func testNothingCanBeDoneOutOfTurn() throws {
        let outOfTurn = "That is not possible right now"
        let library = try GameFixtures.library()
        var fresh = try start()

        XCTAssertThrowsError(try fresh.submit(["s-w-1"])) { XCTAssertEqual(self.message($0), outOfTurn) }
        XCTAssertThrowsError(try fresh.nextRound(shuffle: self.identity)) { XCTAssertEqual(self.message($0), outOfTurn) }
        XCTAssertThrowsError(try fresh.resetAndContinue(library: library, shuffle: self.identity)) {
            XCTAssertEqual(self.message($0), outOfTurn)
        }

        try fresh.ready()
        XCTAssertThrowsError(try fresh.ready()) { XCTAssertEqual(self.message($0), outOfTurn) }
        XCTAssertThrowsError(try fresh.nextRound(shuffle: self.identity)) { XCTAssertEqual(self.message($0), outOfTurn) }

        try fresh.submit(["s-w-1"])
        try fresh.ready()
        try fresh.submit(["s-w-2"])
        XCTAssertThrowsError(try fresh.ready()) { XCTAssertEqual(self.message($0), outOfTurn) }
        XCTAssertThrowsError(try fresh.submit(["s-w-1"])) { XCTAssertEqual(self.message($0), outOfTurn) }
    }

    func testAGameInTheMiddleOfARoundSurvivesBeingSavedAndOpenedAgain() throws {
        var game = try start()
        try game.ready()
        try game.submit(["s-w-1"])

        let restored = try JSONDecoder().decode(Game.self, from: JSONEncoder().encode(game))

        XCTAssertEqual(restored, game)
    }
}
