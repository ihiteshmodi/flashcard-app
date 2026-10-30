import XCTest
@testable import FlashcardsCore

final class SeedDecksTests: XCTestCase {
    private let seed = """
    {"version":1,"decks":[
      {"id":"deep","title":"Deep Talk","cards":[
        {"id":"deep-001","category":"Values","kind":"question","prompt":"Q1"},
        {"id":"deep-002","kind":"topic","prompt":"Q2","detail":"Why it works: it opens up"}]},
      {"id":"pairs","title":"Pairs","cards":[
        {"id":"pairs-001","kind":"multipleChoice","prompt":"Spinach?","options":["Tell them","Say nothing","Mirror"]},
        {"id":"pairs-002","kind":"thisOrThat","prompt":"Coffee or tea","options":["Coffee","Tea"]},
        {"id":"pairs-003","kind":"dare","prompt":"Hold hands","detail":"for a minute"}]}
    ]}
    """

    func testLoadingCreatesTheDecksAndCardsInSourceOrder() throws {
        let world = try World()

        try world.app.loadSeed(Data(seed.utf8))

        let rows = try world.db.rows("SELECT * FROM card ORDER BY deck_id, sort_order")
        XCTAssertEqual(rows.map { $0.string("id") }, ["deep-001", "deep-002", "pairs-001", "pairs-002", "pairs-003"])
        let decks = try world.db.rows("SELECT title FROM deck WHERE is_builtin = 1 ORDER BY sort_order")
        XCTAssertEqual(decks.map { $0.string("title") }, ["Deep Talk", "Pairs"])
    }

    func testEveryCardShapeKeepsItsKindDetailAndOptions() throws {
        let world = try World()
        try world.app.loadSeed(Data(seed.utf8))

        let topic = try world.card(id: "deep-002")
        let choice = try world.card(id: "pairs-001")
        let either = try world.card(id: "pairs-002")
        let dare = try world.card(id: "pairs-003")

        XCTAssertEqual(try world.card(id: "deep-001").category, "Values")
        XCTAssertEqual([topic.kind, choice.kind, either.kind, dare.kind], [.topic, .multipleChoice, .thisOrThat, .dare])
        XCTAssertEqual(topic.detail, "Why it works: it opens up")
        XCTAssertEqual(choice.options, ["Tell them", "Say nothing", "Mirror"])
        XCTAssertEqual(either.options, ["Coffee", "Tea"])
    }

    func testCardTextIsStoredExactlyAsInTheSource() throws {
        let world = try World()
        let verbatim = #"{"version":1,"decks":[{"id":"d","title":"D","cards":[{"id":"d-1","kind":"question","prompt":"What would your gf say? “Quotes” & 1,000"}]}]}"#

        try world.app.loadSeed(Data(verbatim.utf8))

        XCTAssertEqual(try world.card(id: "d-1").prompt, "What would your gf say? “Quotes” & 1,000")
    }

    func testLoadingTwiceDoesNotDuplicateAnything() throws {
        let world = try World()

        try world.app.loadSeed(Data(seed.utf8))
        try world.app.loadSeed(Data(seed.utf8))

        XCTAssertEqual(try world.db.count("SELECT COUNT(*) AS n FROM card"), 5)
        XCTAssertEqual(try world.db.count("SELECT COUNT(*) AS n FROM deck WHERE is_builtin = 1"), 2)
    }

    func testACorrectedCardKeepsAskedMarksAndAnswers() throws {
        let world = try World()
        let maya = try world.person("Maya")
        try world.app.loadSeed(Data(seed.utf8))
        try world.markAsked(["Q1"], for: maya)
        try world.saveAnswerDirectly("Lisbon", card: "Q1", for: maya)

        try world.app.loadSeed(Data(seed.replacingOccurrences(of: "\"Q1\"", with: "\"Q1, corrected\"").utf8))

        XCTAssertEqual(try world.card(id: "deep-001").prompt, "Q1, corrected")
        XCTAssertEqual(try CardStates.status(world.db, profileID: maya.id, cardID: "deep-001"), .asked)
        XCTAssertEqual(try world.db.count("SELECT COUNT(*) AS n FROM answer"), 1)
    }

    func testACardThatLeftTheSeedIsRemovedWhenNobodyUsedIt() throws {
        let world = try World()
        try world.app.loadSeed(Data(seed.utf8))
        let trimmed = #"{"version":1,"decks":[{"id":"deep","title":"Deep Talk","cards":[{"id":"deep-001","kind":"question","prompt":"Q1"}]}]}"#

        try world.app.loadSeed(Data(trimmed.utf8))

        XCTAssertEqual(try world.db.count("SELECT COUNT(*) AS n FROM card WHERE id = 'deep-002'"), 0)
        XCTAssertEqual(try world.db.count("SELECT COUNT(*) AS n FROM card WHERE id = 'deep-001'"), 1)
    }

    func testASplitCardReplacesItsCombinedCardInTheStack() throws {
        let world = try World()
        let maya = try world.person("Maya")
        let combined = #"{"version":1,"decks":[{"id":"g","title":"G","cards":[{"id":"g-001","kind":"question","prompt":"Most? Least?"}]}]}"#
        let split = #"{"version":1,"decks":[{"id":"g","title":"G","cards":[{"id":"g-001a","kind":"question","prompt":"Most?"},{"id":"g-001b","kind":"question","prompt":"Least?"}]}]}"#
        try world.app.loadSeed(Data(combined.utf8))
        try world.app.session(for: maya.id).swipeLeft()

        try world.app.loadSeed(Data(split.utf8))
        let session = try world.app.session(for: maya.id)
        try session.syncWithLibrary()

        XCTAssertEqual(session.stack.map(\.prompt), ["Most?", "Least?"])
    }

    func testACardThatLeftTheSeedIsKeptWhenItWasAskedOrAnswered() throws {
        let world = try World()
        let maya = try world.person("Maya")
        try world.app.loadSeed(Data(seed.utf8))
        try world.markAsked(["Q2"], for: maya)
        let trimmed = #"{"version":1,"decks":[{"id":"deep","title":"Deep Talk","cards":[{"id":"deep-001","kind":"question","prompt":"Q1"}]}]}"#

        try world.app.loadSeed(Data(trimmed.utf8))

        XCTAssertEqual(try world.db.count("SELECT COUNT(*) AS n FROM card WHERE id = 'deep-002'"), 1)
    }

    func testDecksMissingFromAFileAreLeftAloneByThatFile() throws {
        let world = try World()
        try world.app.loadSeed(Data(seed.utf8))
        let other = #"{"version":1,"decks":[{"id":"extra","title":"Extra","cards":[{"id":"extra-1","kind":"question","prompt":"E"}]}]}"#

        try world.app.loadSeed(Data(other.utf8))

        XCTAssertEqual(try world.db.count("SELECT COUNT(*) AS n FROM card WHERE deck_id = 'deep'"), 2)
    }

    func testAnEmptySeedIsAcceptedSoAFreshCloneStillStarts() throws {
        let world = try World()

        try world.app.loadSeed(Data(#"{"version":1,"decks":[]}"#.utf8))

        XCTAssertEqual(try world.db.count("SELECT COUNT(*) AS n FROM card"), 0)
    }

    func testUnreadableSeedDataIsReportedAndChangesNothing() throws {
        let world = try World()

        XCTAssertThrowsError(try world.app.loadSeed(Data("not json".utf8))) { error in
            XCTAssertTrue(error is SeedError)
        }
        XCTAssertEqual(try world.db.count("SELECT COUNT(*) AS n FROM card"), 0)
    }

    func testOneBadCardRollsBackTheWholeLoad() throws {
        let world = try World()
        let bad = #"{"version":1,"decks":[{"id":"d","title":"D","cards":[{"id":"d-1","kind":"question","prompt":"ok"},{"id":"d-2","kind":"nonsense","prompt":"bad"}]}]}"#

        XCTAssertThrowsError(try world.app.loadSeed(Data(bad.utf8)))

        XCTAssertEqual(try world.db.count("SELECT COUNT(*) AS n FROM card"), 0)
    }
}
