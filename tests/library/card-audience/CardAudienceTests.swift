import XCTest
@testable import FlashcardsCore

final class CardAudienceTests: XCTestCase {
    private func mixedDeck(_ world: World) throws {
        try world.deck("Mixed", cards: [
            "Favourite flower?", "Favourite fragrance?", "Do you like my beard?", "First kiss story?",
            "Dream couple holiday?", "Pick a slow dance", "Dare: blindfold", "Men only banter",
        ])
        try world.label("Favourite fragrance?", .women)
        try world.label("Do you like my beard?", .everyone, .safe, .man)
        try world.label("First kiss story?", .everyone, .flirty)
        try world.label("Dream couple holiday?", .couples)
        try world.label("Pick a slow dance", .couples, .flirty)
        try world.label("Dare: blindfold", .couples, .explicit)
        try world.label("Men only banter", .men)
    }

    private func mixedWorld(owner: Gender? = .man) throws -> World {
        let world = try World()
        try world.app.setOwnerGender(owner)
        try mixedDeck(world)
        return world
    }

    private func stackSet(_ world: World, _ profile: Profile) throws -> Set<String> {
        Set(try world.stack(for: profile))
    }

    func testEachKindOfProfileSeesOnlyTheCardsThatSuitIt() throws {
        let everyoneSafe: Set = ["Favourite flower?", "Do you like my beard?"]
        let flirtyAdded: Set = ["First kiss story?", "Dream couple holiday?", "Pick a slow dance"]
        let table: [(Gender, Closeness, Set<String>)] = [
            (.woman, .friend, everyoneSafe.union(["Favourite fragrance?"])),
            (.woman, .dating, everyoneSafe.union(["Favourite fragrance?"]).union(flirtyAdded)),
            (.woman, .partner, everyoneSafe.union(["Favourite fragrance?"]).union(flirtyAdded).union(["Dare: blindfold"])),
            (.man, .friend, everyoneSafe.union(["Men only banter"])),
        ]
        for (gender, closeness, expected) in table {
            let world = try mixedWorld()
            let person = try world.person("Maya", gender: gender, closeness)

            XCTAssertEqual(try stackSet(world, person), expected, "\(gender) \(closeness)")
        }
    }

    func testAPersonWithoutAGenderTagOnlySeesEveryoneAndSafeEvenAsAPartner() throws {
        let world = try mixedWorld()
        let riley = try world.person("Riley", gender: nil, .partner)

        XCTAssertEqual(try stackSet(world, riley), ["Favourite flower?", "Do you like my beard?"])
    }

    func testAGroupOnlySeesEveryoneAndSafe() throws {
        let world = try mixedWorld()
        let maya = try world.person("Maya", gender: .woman, .partner)
        let group = try world.app.groups.createGroup(name: "Game Night", memberIDs: [maya.id])

        XCTAssertEqual(try stackSet(world, group), ["Favourite flower?", "Do you like my beard?"])
    }

    func testCardsWordedFromAManViewAreHiddenWhenIAmNotAMan() throws {
        let world = try mixedWorld(owner: .woman)
        let maya = try world.person("Maya", gender: .woman, .friend)

        XCTAssertEqual(try stackSet(world, maya), ["Favourite flower?", "Favourite fragrance?"])
    }

    func testWithoutAnIAmSettingNoCardWordedFromASpecificViewIsShown() throws {
        let world = try mixedWorld(owner: nil)
        let maya = try world.person("Maya", gender: .woman, .friend)

        XCTAssertEqual(try stackSet(world, maya), ["Favourite flower?", "Favourite fragrance?"])
    }

    func testChangingIAmUpdatesEveryOpenStack() throws {
        let world = try mixedWorld()
        let maya = try world.person("Maya", gender: .woman, .friend)
        XCTAssertTrue(try world.stack(for: maya).contains("Do you like my beard?"))

        try world.app.setOwnerGender(.woman)

        XCTAssertFalse(try world.stack(for: maya).contains("Do you like my beard?"))
    }

    func testProgressCountsOnlyTheCardsThisProfileCanBeAsked() throws {
        let world = try mixedWorld()
        let maya = try world.person("Maya", gender: .woman, .friend)

        XCTAssertEqual(try world.app.session(for: maya.id).progress, Progress(asked: 0, total: 3))
    }

    func testCardsHiddenByLabelsStayInHistoryIfAskedBefore() throws {
        let world = try mixedWorld()
        let maya = try world.person("Maya", gender: .woman, .partner)
        let session = try world.app.session(for: maya.id)
        while session.topCard?.prompt != "Dare: blindfold" { try session.swipeLeft() }
        try session.swipeRight()

        try world.app.setCloseness(of: maya.id, to: .friend)

        XCTAssertTrue(try world.app.answers.history(profileID: maya.id).map(\.card.prompt).contains("Dare: blindfold"))
        XCTAssertFalse(try world.stack(for: maya).contains("Dare: blindfold"))
    }

    func testDeckSwitchesAndLabelsWorkTogether() throws {
        let world = try mixedWorld()
        let maya = try world.person("Maya", gender: .woman, .partner)
        try world.deck("Other", cards: ["Spare"])

        try world.app.decks.setDeck("mixed", on: false, for: maya.id)

        XCTAssertEqual(try world.stack(for: maya), ["Spare"])
    }

    func testDeckChoicesCountOnlyTheCardsThatProfileCanSee() throws {
        let world = try mixedWorld()
        let maya = try world.person("Maya", gender: .woman, .friend)

        XCTAssertEqual(try world.app.decks.rows(for: maya.id).map(\.cardCount), [3])
    }

    func testBundledCardsWithoutLabelsDefaultToEveryoneSafeAnyone() throws {
        let world = try World()
        let card = try XCTUnwrap(try world.deck("Plain", cards: ["Q"]).first)

        XCTAssertEqual(card.audience, .everyone)
        XCTAssertEqual(card.spice, .safe)
        XCTAssertEqual(card.perspective, .anyone)
    }

    func testTheSeedCarriesLabelsAndTheyUpdateOnReload() throws {
        let world = try World()
        func seed(_ spice: String) -> Data {
            Data("""
            {"version":1,"decks":[{"id":"d","title":"D","cards":[
              {"id":"c1","kind":"question","prompt":"Q1","audience":"couples","spice":"\(spice)","perspective":"man"},
              {"id":"c2","kind":"question","prompt":"Q2"}]}]}
            """.utf8)
        }

        try world.app.loadSeed(seed("flirty"))
        let first = try world.card(id: "c1")
        try world.app.loadSeed(seed("explicit"))

        XCTAssertEqual(first.audience, .couples)
        XCTAssertEqual(first.spice, .flirty)
        XCTAssertEqual(first.perspective, .man)
        XCTAssertEqual(try world.card(id: "c1").spice, .explicit)
        XCTAssertEqual(try world.card(id: "c2").audience, .everyone)
    }
}
