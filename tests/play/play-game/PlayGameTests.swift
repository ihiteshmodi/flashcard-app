import XCTest
@testable import FlashcardsCore

final class PlayGameTests: XCTestCase {
    private let identity: ([String]) -> [String] = { $0 }
    private let reversed: ([String]) -> [String] = { Array($0.reversed()) }

    private func start(_ players: [String] = ["Maya", "Sam", "Lee"], whites: Int = 60,
                       blacks: [String] = GameFixtures.blacks,
                       sets: Set<String> = ["s"], shuffle: ([String]) -> [String] = { $0 }) throws -> Game {
        try Game.start(players: players, library: try GameFixtures.library(whites: whites, blacks: blacks), sets: sets, shuffle: shuffle)
    }

    private func everyoneButTheCzarPlays(_ game: inout Game) throws {
        while case .passToPlayer = game.phase {
            try game.ready()
            try game.play(game.visibleHand.prefix(game.blackCard.pick).map(\.id))
        }
    }

    private func judging(_ shuffle: ([String]) -> [String] = { $0 }) throws -> Game {
        var game = try start(shuffle: shuffle)
        try everyoneButTheCzarPlays(&game)
        try game.ready()
        return game
    }

    private func wonRoundOne() throws -> Game {
        var game = try judging()
        try game.choose(playAt: 1)
        return game
    }

    private func message(_ error: Error) -> String { error.localizedDescription }

    // MARK: Starting

    func testEveryPlayerHoldsTenWhiteCardsWhenTheGameStarts() throws {
        let game = try start()

        XCTAssertEqual(game.players.map { game.hands[$0]?.count }, [10, 10, 10])
    }

    func testTheFirstBlackCardIsTurnedAndTheFirstPlayerIsTheCzar() throws {
        let game = try start()

        XCTAssertEqual(game.blackCard.id, "s-b-1")
        XCTAssertEqual(game.czar, "Maya")
        XCTAssertEqual(game.round, 1)
    }

    func testEveryoneStartsWithNoPoints() throws {
        XCTAssertEqual(try start().scoreboard.map(\.points), [0, 0, 0])
    }

    func testThePlayersNamesAreKeptInTheOrderTheyWereTyped() throws {
        XCTAssertEqual(try start([" Maya ", "Sam", "Lee"]).players, ["Maya", "Sam", "Lee"])
    }

    func testAGameNeedsThreeToTenPlayersWithDifferentNames() throws {
        let eleven = (1...11).map { "P\($0)" }
        let cases: [(String, [String], String)] = [
            ("two players", ["Maya", "Sam"], "Add at least 3 players"),
            ("eleven players", eleven, "A game takes at most 10 players"),
            ("the same name in another case", ["Maya", "Sam", "maya"], "Each player needs a different name"),
            ("a blank name", ["Maya", "Sam", " "], "Every player needs a name"),
        ]
        for (name, players, expected) in cases {
            XCTAssertThrowsError(try start(players), name) { XCTAssertEqual(self.message($0), expected, name) }
        }
    }

    func testAGameNeedsACardSet() throws {
        XCTAssertThrowsError(try start(sets: [])) { XCTAssertEqual(self.message($0), "Switch on at least one card set") }
    }

    func testTheChosenSetsMustHoldEnoughWhiteCardsForTheHands() throws {
        XCTAssertThrowsError(try start(whites: 29)) {
            XCTAssertEqual(self.message($0), "These sets do not have enough white cards for 3 players")
        }
    }

    func testTheChosenSetsMustHoldABlackCard() throws {
        XCTAssertThrowsError(try start(blacks: [])) { XCTAssertEqual(self.message($0), "These sets have no black cards") }
    }

    // MARK: Hidden hands and turns

    func testTheNextPlayerIsAskedForBeforeAnyHandIsShown() throws {
        let game = try start()

        XCTAssertEqual(game.phase, .passToPlayer("Sam"))
        XCTAssertEqual(game.visibleHand, [])
    }

    func testAPlayerSeesOnlyTheirOwnHandOnceTheySayItIsThem() throws {
        var game = try start()

        try game.ready()

        XCTAssertEqual(game.phase, .choosing("Sam"))
        XCTAssertEqual(game.visibleHand.map(\.id), (11...20).map { "s-w-\($0)" })
    }

    func testPlayersPlayInTurnAfterTheCzarAndTheCzarIsAskedForLast() throws {
        var game = try start()

        try game.ready()
        try game.play(["s-w-11"])
        XCTAssertEqual(game.phase, .passToPlayer("Lee"))
        try game.ready()
        try game.play(["s-w-21"])

        XCTAssertEqual(game.phase, .passToCzar)
        XCTAssertEqual(game.visibleHand, [])
    }

    func testAPlayedCardLeavesTheHand() throws {
        var game = try start()
        try game.ready()

        try game.play(["s-w-11"])

        XCTAssertEqual(game.hands["Sam"]?.count, 9)
    }

    // MARK: Playing cards

    func testAPlayerMustPlayAsManyCardsAsTheBlackCardAsksFor() throws {
        var game = try start(blacks: ["_____ is a slippery slope that leads to _____."])
        try game.ready()

        XCTAssertThrowsError(try game.play(["s-w-11"])) { XCTAssertEqual(self.message($0), "Choose 2 cards") }
        XCTAssertNoThrow(try game.play(["s-w-11", "s-w-12"]))
    }

    func testAPlayerCanOnlyPlayCardsFromTheirOwnHand() throws {
        var game = try start()
        try game.ready()

        XCTAssertThrowsError(try game.play(["s-w-1"])) { XCTAssertEqual(self.message($0), "That card is not in your hand") }
    }

    func testAPlayerCannotPlayTheSameCardTwice() throws {
        var game = try start(blacks: ["_____ and _____."])
        try game.ready()

        XCTAssertThrowsError(try game.play(["s-w-11", "s-w-11"])) { XCTAssertEqual(self.message($0), "Choose different cards") }
    }

    func testARefusedPlayChangesNothing() throws {
        var game = try start()
        try game.ready()
        let before = game

        _ = try? game.play(["s-w-1"])

        XCTAssertEqual(game, before)
    }

    // MARK: Judging

    func testTheCzarSeesEveryPlayInTheOrderTheShuffleGave() throws {
        let game = try judging(reversed)

        // The reversed deck gives Sam s-w-50 and Lee s-w-40; the reversed order shows Lee's play first.
        XCTAssertEqual(game.plays.map { $0.cards.map(\.id) }, [["s-w-40"], ["s-w-50"]])
    }

    func testThePlaysAreNotShownBeforeTheCzarIsJudging() throws {
        var game = try start()
        try everyoneButTheCzarPlays(&game)

        XCTAssertEqual(game.phase, .passToCzar)
        XCTAssertEqual(game.plays, [])
    }

    func testThePlayOfAPlayerWhoPlayedTwoCardsKeepsTheirOrder() throws {
        var game = try start(blacks: ["_____ and _____."])
        try everyoneButTheCzarPlays(&game)
        try game.ready()

        XCTAssertEqual(game.plays.first?.cards.map(\.id), ["s-w-11", "s-w-12"])
    }

    func testTheWinnerOfTheRoundIsNamedAndScoresOnePoint() throws {
        var game = try judging()

        try game.choose(playAt: 1)

        guard case .roundResult(let winner, let play) = game.phase else { return XCTFail("not a result: \(game.phase)") }
        XCTAssertEqual(winner, "Lee")
        XCTAssertEqual(play.cards.map(\.id), ["s-w-21"])
        XCTAssertEqual(game.scoreboard.map(\.points), [0, 0, 1])
    }

    func testAPlayThatDoesNotExistCannotBeChosen() throws {
        var game = try judging()

        XCTAssertThrowsError(try game.choose(playAt: 2)) { XCTAssertEqual(self.message($0), "That play does not exist") }
    }

    // MARK: Next round

    func testTheNextRoundPassesTheCzarOnAndAsksForTheFirstPlayerAfterThem() throws {
        var game = try wonRoundOne()

        try game.nextRound(shuffle: identity)

        XCTAssertEqual(game.czar, "Sam")
        XCTAssertEqual(game.round, 2)
        XCTAssertEqual(game.phase, .passToPlayer("Lee"))
    }

    func testTheNextRoundTurnsANewBlackCard() throws {
        var game = try wonRoundOne()

        try game.nextRound(shuffle: identity)

        XCTAssertEqual(game.blackCard.id, "s-b-2")
    }

    func testTheNextRoundRefillsEveryHandToTen() throws {
        var game = try wonRoundOne()

        try game.nextRound(shuffle: identity)

        XCTAssertEqual(game.players.map { game.hands[$0]?.count }, [10, 10, 10])
    }

    func testThePointsAreKeptFromRoundToRound() throws {
        var game = try wonRoundOne()

        try game.nextRound(shuffle: identity)

        XCTAssertEqual(game.scoreboard.map(\.points), [0, 0, 1])
    }

    func testCardsPlayedComeBackWhenTheWhitePileRunsOutAndNoCardIsHeldTwice() throws {
        var game = try start(whites: 30)
        try everyoneButTheCzarPlays(&game)
        try game.ready()
        try game.choose(playAt: 0)

        try game.nextRound(shuffle: identity)

        let held = game.players.flatMap { game.hands[$0] ?? [] }.map(\.id)
        XCTAssertEqual(held.count, 30)
        XCTAssertEqual(Set(held).count, 30)
    }

    func testTheBlackCardsComeRoundAgainWhenTheyRunOut() throws {
        var game = try start(blacks: ["One _____.", "Two _____."])
        var turned: [String] = [game.blackCard.id]
        for _ in 1...3 {
            try everyoneButTheCzarPlays(&game)
            try game.ready()
            try game.choose(playAt: 0)
            try game.nextRound(shuffle: identity)
            turned.append(game.blackCard.id)
        }

        XCTAssertEqual(turned, ["s-b-1", "s-b-2", "s-b-1", "s-b-2"])
    }

    func testTheCzarRotatesBackToTheFirstPlayer() throws {
        var game = try start()
        for _ in 1...3 {
            try everyoneButTheCzarPlays(&game)
            try game.ready()
            try game.choose(playAt: 0)
            try game.nextRound(shuffle: identity)
        }

        XCTAssertEqual(game.czar, "Maya")
    }

    // MARK: Nothing out of turn

    func testNothingCanBeDoneOutOfTurn() throws {
        let outOfTurn = "That is not possible right now"
        var fresh = try start()
        var judge = try judging()
        var done = try wonRoundOne()

        XCTAssertThrowsError(try fresh.play(["s-w-11"])) { XCTAssertEqual(self.message($0), outOfTurn) }
        XCTAssertThrowsError(try fresh.choose(playAt: 0)) { XCTAssertEqual(self.message($0), outOfTurn) }
        XCTAssertThrowsError(try fresh.nextRound(shuffle: self.identity)) { XCTAssertEqual(self.message($0), outOfTurn) }
        XCTAssertThrowsError(try judge.play(["s-w-1"])) { XCTAssertEqual(self.message($0), outOfTurn) }
        XCTAssertThrowsError(try judge.ready()) { XCTAssertEqual(self.message($0), outOfTurn) }
        XCTAssertThrowsError(try judge.nextRound(shuffle: self.identity)) { XCTAssertEqual(self.message($0), outOfTurn) }
        XCTAssertThrowsError(try done.choose(playAt: 0)) { XCTAssertEqual(self.message($0), outOfTurn) }
        XCTAssertThrowsError(try done.ready()) { XCTAssertEqual(self.message($0), outOfTurn) }
    }

    func testPlayingWhileTheNextPlayerIsStillBeingAskedForIsRefused() throws {
        var game = try start()
        try game.ready()

        XCTAssertThrowsError(try game.ready()) { XCTAssertEqual(self.message($0), "That is not possible right now") }
    }

    // MARK: Scores

    func testTheScoreboardListsEveryoneInTheOrderTheyWereTypedAndMarksTheCzar() throws {
        let game = try wonRoundOne()

        XCTAssertEqual(game.scoreboard.map(\.name), ["Maya", "Sam", "Lee"])
        XCTAssertEqual(game.scoreboard.map(\.points), [0, 0, 1])
        XCTAssertEqual(game.scoreboard.map(\.isCzar), [true, false, false])
    }

    func testAGameInTheMiddleOfARoundSurvivesBeingSavedAndOpenedAgain() throws {
        var game = try start()
        try game.ready()
        try game.play(["s-w-11"])

        let restored = try JSONDecoder().decode(Game.self, from: JSONEncoder().encode(game))

        XCTAssertEqual(restored, game)
    }
}
