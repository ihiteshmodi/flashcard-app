import XCTest
@testable import FlashcardsCore

final class GameScreenTests: XCTestCase {
    private func game() throws -> Game {
        try Game.start(players: ["Maya", "Sam", "Lee"], library: try GameFixtures.library(), sets: ["s"], shuffle: { $0 })
    }

    private func play(_ game: inout Game) throws {
        try game.ready()
        try game.play([game.visibleHand[0].id])
    }

    func testTheFirstScreenAsksForThePhoneToBePassedWithoutShowingAnyCards() throws {
        XCTAssertEqual(try game().screen, .passPhone(to: "Sam", isCzar: false))
    }

    func testAPlayerWhoSaysItIsThemSeesTheBlackCardAndTheirOwnHand() throws {
        var game = try game()

        try game.ready()

        XCTAssertEqual(game.screen, .chooseCards(player: "Sam", black: game.blackCard, hand: game.visibleHand))
        XCTAssertEqual(game.visibleHand.count, 10)
    }

    func testAfterTheLastPlayerThePhoneGoesToTheCzar() throws {
        var game = try game()
        try play(&game)
        try play(&game)

        XCTAssertEqual(game.screen, .passPhone(to: "Maya", isCzar: true))
    }

    func testTheCzarSeesTheBlackCardAndTheAnonymousPlays() throws {
        var game = try game()
        try play(&game)
        try play(&game)

        try game.ready()

        XCTAssertEqual(game.screen, .judge(czar: "Maya", black: game.blackCard, plays: game.plays))
        XCTAssertEqual(game.plays.count, 2)
    }

    func testTheResultNamesTheWinnerAndShowsTheScores() throws {
        var game = try game()
        try play(&game)
        try play(&game)
        try game.ready()
        try game.choose(playAt: 1)

        guard case .roundResult(let winner, let black, let winningPlay, let scoreboard) = game.screen else {
            return XCTFail("not a result: \(game.screen)")
        }
        XCTAssertEqual(winner, "Lee")
        XCTAssertEqual(black, game.blackCard)
        XCTAssertEqual(winningPlay.cards.map(\.id), ["s-w-21"])
        XCTAssertEqual(scoreboard.map(\.points), [0, 0, 1])
    }
}

final class CardPickerTests: XCTestCase {
    func testAPickOfOneTakesTheLastCardTouched() {
        var picker = CardPicker(pick: 1)

        picker.toggle("a")
        picker.toggle("b")

        XCTAssertEqual(picker.selected, ["b"])
        XCTAssertTrue(picker.isComplete)
    }

    func testAPickOfTwoKeepsTheOrderTheCardsWereChosenIn() {
        var picker = CardPicker(pick: 2)

        picker.toggle("b")
        picker.toggle("a")

        XCTAssertEqual(picker.selected, ["b", "a"])
        XCTAssertEqual(picker.position(of: "a"), 2)
        XCTAssertTrue(picker.isComplete)
    }

    func testTouchingAChosenCardChoosesItAgain() {
        var picker = CardPicker(pick: 2)
        picker.toggle("a")
        picker.toggle("b")

        picker.toggle("a")

        XCTAssertEqual(picker.selected, ["b"])
        XCTAssertFalse(picker.isComplete)
        XCTAssertNil(picker.position(of: "a"))
    }

    func testNoMoreCardsThanTheBlackCardAsksForCanBeChosenAtOnce() {
        var picker = CardPicker(pick: 2)
        picker.toggle("a")
        picker.toggle("b")

        picker.toggle("c")

        XCTAssertEqual(picker.selected, ["a", "b"])
    }

    func testNothingIsCompleteBeforeAnyCardIsChosen() {
        XCTAssertFalse(CardPicker(pick: 1).isComplete)
    }
}
