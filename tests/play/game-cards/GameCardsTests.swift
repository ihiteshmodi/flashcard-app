import XCTest
@testable import FlashcardsCore

final class GameCardsTests: XCTestCase {
    private func file(_ sets: String) -> Data { Data(#"{"version":1,"sets":[\#(sets)]}"#.utf8) }

    private let family = #"""
    {"id":"family","title":"Family","black":[{"id":"family-b-1","text":"Coming soon! Batman vs. _____."}],
     "white":[{"id":"family-w-1","text":"Ratzilla."}]}
    """#

    private let adult = #"""
    {"id":"adult","title":"Adult","black":[{"id":"adult-b-1","text":"What ended my last relationship?"}],
     "white":[{"id":"adult-w-1","text":"Ratzilla."}]}
    """#

    private func library(_ sets: String...) throws -> GameCardLibrary {
        try GameCardLibrary(files: [file(sets.joined(separator: ","))])
    }

    func testASetKnowsItsTitleAndHoldsItsBlackAndWhiteCards() throws {
        let library = try library(family)

        XCTAssertEqual(library.sets.map(\.title), ["Family"])
        XCTAssertEqual(library.sets[0].blackCards.map(\.text), ["Coming soon! Batman vs. _____."])
        XCTAssertEqual(library.sets[0].whiteCards.map(\.text), ["Ratzilla."])
    }

    func testABlackCardWithOneBlankAsksForOneWhiteCard() throws {
        XCTAssertEqual(try library(family).sets[0].blackCards[0].pick, 1)
    }

    func testAQuestionCardAsksForOneWhiteCard() throws {
        XCTAssertEqual(try library(adult).sets[0].blackCards[0].pick, 1)
    }

    func testABlackCardWithTwoBlanksAsksForTwoWhiteCards() throws {
        let twoBlanks = #"{"id":"s","title":"S","black":[{"id":"s-b-1","text":"_____ is a slippery slope that leads to _____."}],"white":[]}"#

        XCTAssertEqual(try library(twoBlanks).sets[0].blackCards[0].pick, 2)
    }

    func testABlackCardCanStateItsOwnPickWhenBlanksDoNotShowIt() throws {
        let explicit = #"{"id":"s","title":"S","black":[{"id":"s-b-1","text":"Make a haiku.","pick":3}],"white":[]}"#

        XCTAssertEqual(try library(explicit).sets[0].blackCards[0].pick, 3)
    }

    func testOnlyTheEnabledSetsAreDealt() throws {
        let library = try library(family, adult)

        XCTAssertEqual(library.blackCards(in: ["family"]).map(\.text), ["Coming soon! Batman vs. _____."])
        XCTAssertEqual(library.whiteCards(in: ["family"]).map(\.id), ["family-w-1"])
    }

    func testACardInTwoEnabledSetsIsDealtOnce() throws {
        let library = try library(family, adult)

        XCTAssertEqual(library.whiteCards(in: ["family", "adult"]).map(\.id), ["family-w-1"])
        XCTAssertEqual(library.blackCards(in: ["family", "adult"]).count, 2)
    }

    func testCardsThatDifferOnlyByCaseAndSpacingCountAsTheSameCard() throws {
        let other = #"{"id":"other","title":"Other","black":[],"white":[{"id":"other-w-1","text":"  ratzilla.  "}]}"#

        XCTAssertEqual(try library(family, other).whiteCards(in: ["family", "other"]).count, 1)
    }

    func testSeveralFilesAddTheirSetsInOrder() throws {
        let library = try GameCardLibrary(files: [file(family), file(adult)])

        XCTAssertEqual(library.sets.map(\.id), ["family", "adult"])
    }

    func testAnUnreadableFileReportsWhyTheCardDataCouldNotBeRead() {
        XCTAssertThrowsError(try GameCardLibrary(files: [Data("not json".utf8)])) { error in
            XCTAssertTrue(error.localizedDescription.hasPrefix("The card data could not be read"))
        }
    }

    func testTwoCardsWithTheSameIdAreRefused() {
        let clash = #"{"id":"s","title":"S","black":[],"white":[{"id":"w","text":"A"},{"id":"w","text":"B"}]}"#

        XCTAssertThrowsError(try library(clash))
    }
}
