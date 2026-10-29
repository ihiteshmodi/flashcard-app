import XCTest
@testable import FlashcardsCore

final class ManageGroupsTests: XCTestCase {
    private func world() throws -> (World, [String: Profile]) {
        let world = try World()
        try world.deck("Deep Talk", cards: ["Q1", "Q2", "Q3"])
        var people: [String: Profile] = [:]
        for name in ["Maya", "Sam", "Jordan", "Alex", "Riley"] { people[name] = try world.person(name) }
        return (world, people)
    }

    private func ids(_ people: [String: Profile], _ names: [String]) -> [String] { names.compactMap { people[$0]?.id } }

    func testCreatingAGroupFromExistingPeopleListsItWithItsMembersAndSelectsIt() throws {
        let (world, people) = try world()

        let group = try world.app.groups.createGroup(
            name: "College Friends", emoji: "🍻", memberIDs: ids(people, ["Maya", "Sam", "Jordan", "Alex"]))

        let summary = try XCTUnwrap(try world.app.profiles.groups().first)
        XCTAssertEqual(summary.profile, group)
        XCTAssertEqual(summary.memberCount, 4)
        XCTAssertEqual(try world.app.profiles.selectedProfile(), group)
        XCTAssertEqual(try world.app.profiles.people().count, 5)
    }

    func testAGroupNeedsAName() throws {
        let (world, people) = try world()

        XCTAssertThrowsError(try world.app.groups.createGroup(name: " ", memberIDs: ids(people, ["Maya"]))) {
            XCTAssertEqual($0.localizedDescription, "Enter a name")
        }
        XCTAssertEqual(try world.app.profiles.groups(), [])
    }

    func testAGroupNeedsAtLeastOneMemberAndLeavesNothingBehind() throws {
        let (world, people) = try world()
        let before = try world.app.profiles.selectedProfile()

        XCTAssertThrowsError(try world.app.groups.createGroup(name: "Game Night", memberIDs: [])) {
            XCTAssertEqual($0.localizedDescription, "Pick at least one person")
        }

        XCTAssertEqual(try world.app.profiles.groups(), [])
        XCTAssertEqual(try world.app.profiles.selectedProfile(), before)
        XCTAssertEqual(people.count, 5)
    }

    func testGroupAndPersonNamesCannotClash() throws {
        let (world, people) = try world()

        XCTAssertThrowsError(try world.app.groups.createGroup(name: "maya", memberIDs: ids(people, ["Sam"]))) {
            XCTAssertEqual($0.localizedDescription, "A profile named Maya already exists")
        }
    }

    func testMembersCanBeAddedAndRemoved() throws {
        let (world, people) = try world()
        let group = try world.app.groups.createGroup(name: "College Friends", memberIDs: ids(people, ["Maya", "Sam"]))

        try world.app.groups.addMembers(ids(people, ["Jordan"]), to: group.id)
        try world.app.groups.removeMember(try XCTUnwrap(people["Sam"]).id, from: group.id)

        XCTAssertEqual(try world.app.groups.members(of: group.id).map(\.name), ["Jordan", "Maya"])
    }

    func testAddingAMemberTwiceKeepsOneEntry() throws {
        let (world, people) = try world()
        let group = try world.app.groups.createGroup(name: "G", memberIDs: ids(people, ["Maya"]))

        try world.app.groups.addMembers(ids(people, ["Maya"]), to: group.id)

        XCTAssertEqual(try world.app.groups.members(of: group.id).count, 1)
    }

    func testAGroupCannotBeAMemberOfAGroup() throws {
        let (world, people) = try world()
        let first = try world.app.groups.createGroup(name: "First", memberIDs: ids(people, ["Maya"]))
        let second = try world.app.groups.createGroup(name: "Second", memberIDs: ids(people, ["Sam"]))

        try world.app.groups.addMembers([first.id], to: second.id)

        XCTAssertEqual(try world.app.groups.members(of: second.id).map(\.name), ["Sam"])
    }

    func testTheLastMemberCannotBeRemoved() throws {
        let (world, people) = try world()
        let riley = try XCTUnwrap(people["Riley"])
        let group = try world.app.groups.createGroup(name: "Game Night", memberIDs: [riley.id])

        XCTAssertThrowsError(try world.app.groups.removeMember(riley.id, from: group.id)) {
            XCTAssertEqual($0.localizedDescription, "A group needs at least one person")
        }
        XCTAssertEqual(try world.app.groups.members(of: group.id), [riley])
    }

    func testAGroupHasItsOwnAskedList() throws {
        let (world, people) = try world()
        let maya = try XCTUnwrap(people["Maya"])
        try world.markAsked(["Q1"], for: maya)
        let group = try world.app.groups.createGroup(name: "College Friends", memberIDs: [maya.id])

        XCTAssertEqual(try world.app.session(for: group.id).stack.map(\.prompt), ["Q1", "Q2", "Q3"])
    }

    func testAskingInAGroupDoesNotMarkTheCardForMembers() throws {
        let (world, people) = try world()
        let maya = try XCTUnwrap(people["Maya"])
        let group = try world.app.groups.createGroup(name: "College Friends", memberIDs: [maya.id])

        try world.app.session(for: group.id).swipeRight()

        XCTAssertEqual(try world.app.session(for: group.id).progress.asked, 1)
        XCTAssertEqual(try world.app.session(for: maya.id).progress.asked, 0)
    }

    func testAskingAMemberDoesNotMarkTheCardForTheirGroup() throws {
        let (world, people) = try world()
        let maya = try XCTUnwrap(people["Maya"])
        let group = try world.app.groups.createGroup(name: "College Friends", memberIDs: [maya.id])

        try world.app.session(for: maya.id).swipeRight()

        XCTAssertEqual(try world.app.session(for: group.id).progress.asked, 0)
    }

    func testGroupAnswersAreLabelledWithWhoAnsweredAndStayOutOfThePersonsHistory() throws {
        let (world, people) = try world()
        let sam = try XCTUnwrap(people["Sam"])
        let group = try world.app.groups.createGroup(name: "College Friends", memberIDs: [sam.id])
        let card = try XCTUnwrap(try world.app.session(for: group.id).swipeRight())

        try world.app.answers.save(profileID: group.id, cardID: card.id, text: "Calls park security", pickIndex: nil, answeredBy: "Sam")

        XCTAssertEqual(try world.app.answers.history(profileID: group.id).first?.answer?.answeredBy, "Sam")
        XCTAssertEqual(try world.app.answers.history(profileID: sam.id), [])
    }

    func testWhoAnsweredIsOptionalAndDefaultsToEveryone() throws {
        let (world, people) = try world()
        let group = try world.app.groups.createGroup(name: "College Friends", memberIDs: ids(people, ["Sam"]))
        let card = try XCTUnwrap(try world.app.session(for: group.id).swipeRight())

        try world.app.answers.save(profileID: group.id, cardID: card.id, text: "Everyone laughed", pickIndex: nil)

        XCTAssertEqual(try world.app.answers.answer(profileID: group.id, cardID: card.id)?.answeredBy, "Everyone")
    }

    func testTheAnswererPickerListsCurrentMembersThenEveryone() throws {
        let (world, people) = try world()
        let group = try world.app.groups.createGroup(name: "Game Night", memberIDs: ids(people, ["Riley", "Alex"]))

        XCTAssertEqual(try world.app.answers.answerers(forGroup: group.id), ["Alex", "Riley", "Everyone"])
    }

    func testAGroupHasItsOwnDeckChoicesThatStartOn() throws {
        let (world, people) = try world()
        try world.deck("Dares", cards: ["D1"], kind: .dare)
        try world.app.decks.setDeck("dares", on: false, for: try XCTUnwrap(people["Maya"]).id)

        let group = try world.app.groups.createGroup(name: "College Friends", memberIDs: ids(people, ["Maya"]))

        XCTAssertEqual(try world.app.decks.rows(for: group.id).map(\.isOn), [true, true])
    }

    func testRemovingAPersonFromAGroupKeepsTheirPastGroupAnswers() throws {
        let (world, people) = try world()
        let group = try world.app.groups.createGroup(name: "College Friends", memberIDs: ids(people, ["Sam", "Maya"]))
        let card = try XCTUnwrap(try world.app.session(for: group.id).swipeRight())
        try world.app.answers.save(profileID: group.id, cardID: card.id, text: "Calls park security", pickIndex: nil, answeredBy: "Sam")

        try world.app.groups.removeMember(try XCTUnwrap(people["Sam"]).id, from: group.id)

        XCTAssertEqual(try world.app.answers.history(profileID: group.id).first?.answer?.answeredBy, "Sam")
    }

    func testDeletingAPersonLeavesGroupsIntactAndKeepsTheirLabelledAnswers() throws {
        let (world, people) = try world()
        let sam = try XCTUnwrap(people["Sam"])
        let group = try world.app.groups.createGroup(name: "College Friends", memberIDs: ids(people, ["Sam", "Maya"]))
        let card = try XCTUnwrap(try world.app.session(for: group.id).swipeRight())
        try world.app.answers.save(profileID: group.id, cardID: card.id, text: "Calls park security", pickIndex: nil, answeredBy: "Sam")

        try world.app.profiles.delete(sam.id)

        XCTAssertEqual(try world.app.groups.members(of: group.id).map(\.name), ["Maya"])
        XCTAssertEqual(try world.app.answers.history(profileID: group.id).first?.answer?.answeredBy, "Sam")
        XCTAssertEqual(try world.app.profiles.profile(group.id), group)
    }

    func testDeletingAGroupLeavesItsMembersAndTheirHistoriesUntouched() throws {
        let (world, people) = try world()
        let maya = try XCTUnwrap(people["Maya"])
        try world.markAsked(["Q1"], for: maya)
        let group = try world.app.groups.createGroup(name: "College Friends", memberIDs: [maya.id])
        try world.app.session(for: group.id).swipeRight()

        XCTAssertEqual(try world.app.profiles.impactOfDeleting(group.id).asked, 1)
        try world.app.profiles.delete(group.id)

        XCTAssertEqual(try world.app.profiles.groups(), [])
        XCTAssertEqual(try world.app.profiles.people().first { $0.profile == maya }?.progress.asked, 1)
    }

    func testSwitchingBetweenAPersonAndAGroupKeepsEachStack() throws {
        let (world, people) = try world()
        let maya = try XCTUnwrap(people["Maya"])
        let group = try world.app.groups.createGroup(name: "College Friends", memberIDs: [maya.id])
        try world.app.session(for: maya.id).swipeRight()

        try world.app.profiles.select(group.id)
        XCTAssertEqual(try world.app.session(for: group.id).stack.count, 3)
        try world.app.profiles.select(maya.id)

        XCTAssertEqual(try world.app.session(for: maya.id).stack.count, 2)
    }
}
