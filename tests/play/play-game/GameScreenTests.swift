import XCTest
@testable import FlashcardsCore

final class GameScreenTests: XCTestCase {
    private func game(blacks: [String] = GameFixtures.blacks, excluded: Set<String> = []) throws -> Game {
        try Game.start(
            players: GameFixtures.players("Maya", "Sam"),
            library: try GameFixtures.library(blacks: blacks),
            sets: ["s"],
            excludedBlackIDs: excluded,
            shuffle: { $0 })
    }

    func testTheFirstScreenAsksToPassThePhoneToTheFirstPlayerWithoutShowingAnyCards() throws {
        let current = try game()

        XCTAssertEqual(current.screen, .passPhone(to: GameFixtures.players("Maya")[0]))
    }

    func testAPlayerWhoSaysItIsThemSeesTheBlackCardAndTheTwelveSharedOptions() throws {
        var current = try game()

        try current.ready()

        XCTAssertEqual(
            current.screen,
            .chooseCards(player: GameFixtures.players("Maya")[0], black: current.blackCard, options: current.visibleOptions))
        XCTAssertEqual(current.visibleOptions.count, 12)
    }

    func testAfterTheLastPlayerSubmitsTheScreenRevealsEveryPlayersNamedAnswer() throws {
        var current = try game()
        try current.ready()
        try current.submit(["s-w-1"])
        try current.ready()
        try current.submit(["s-w-2"])

        guard case .reveal(let black, let answers) = current.screen else {
            return XCTFail("expected reveal, got \(current.screen)")
        }
        XCTAssertEqual(black, current.blackCard)
        XCTAssertEqual(answers.map(\.player.name), ["Maya", "Sam"])
        XCTAssertEqual(answers.map { $0.cards.map(\.id) }, [["s-w-1"], ["s-w-2"]])
    }

    func testWhenEveryBlackCardWasAlreadyPlayedTheScreenShowsAllAsked() throws {
        let current = try game(blacks: ["One _____."], excluded: ["s-b-1"])

        XCTAssertEqual(current.screen, .allAsked)
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
