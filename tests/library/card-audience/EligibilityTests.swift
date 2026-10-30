import XCTest
@testable import FlashcardsCore

final class EligibilityTests: XCTestCase {
    private func card(_ audience: Audience, _ spice: Spice, _ perspective: Perspective = .anyone) -> Card {
        Card(id: "c", deckID: "d", category: nil, kind: .question, prompt: "Q", detail: nil, options: [],
             isBuiltIn: true, audience: audience, spice: spice, perspective: perspective)
    }

    private func shown(_ card: Card, gender: Gender?, _ closeness: Closeness, group: Bool = false, owner: Gender? = .man) -> Bool {
        Eligibility(gender: gender, closeness: closeness, isGroup: group, owner: owner).allows(card)
    }

    func testSafeCardsForEveryoneAreShownToEveryone() {
        let plain = card(.everyone, .safe)

        XCTAssertTrue(shown(plain, gender: .woman, .friend))
        XCTAssertTrue(shown(plain, gender: .man, .friend))
        XCTAssertTrue(shown(plain, gender: nil, .friend))
        XCTAssertTrue(shown(plain, gender: nil, .friend, group: true))
    }

    func testSpiceFollowsCloseness() {
        let flirty = card(.everyone, .flirty)
        let explicit = card(.everyone, .explicit)

        XCTAssertFalse(shown(flirty, gender: .woman, .friend))
        XCTAssertTrue(shown(flirty, gender: .woman, .dating))
        XCTAssertTrue(shown(flirty, gender: .woman, .partner))
        XCTAssertFalse(shown(explicit, gender: .woman, .friend))
        XCTAssertFalse(shown(explicit, gender: .woman, .dating))
        XCTAssertTrue(shown(explicit, gender: .woman, .partner))
    }

    func testCouplesCardsNeedDatingOrPartner() {
        let couples = card(.couples, .safe)

        XCTAssertFalse(shown(couples, gender: .woman, .friend))
        XCTAssertTrue(shown(couples, gender: .woman, .dating))
        XCTAssertTrue(shown(couples, gender: .man, .partner))
    }

    func testGenderedAudiencesMatchTheTaggedGenderOnly() {
        let women = card(.women, .safe)
        let men = card(.men, .safe)

        XCTAssertTrue(shown(women, gender: .woman, .friend))
        XCTAssertFalse(shown(women, gender: .man, .friend))
        XCTAssertTrue(shown(men, gender: .man, .friend))
        XCTAssertFalse(shown(men, gender: .woman, .friend))
    }

    func testAPersonWithoutAGenderTagSeesOnlyEveryoneAndSafeEvenWhenAPartner() {
        XCTAssertFalse(shown(card(.women, .safe), gender: nil, .partner))
        XCTAssertFalse(shown(card(.couples, .safe), gender: nil, .partner))
        XCTAssertFalse(shown(card(.everyone, .flirty), gender: nil, .partner))
        XCTAssertTrue(shown(card(.everyone, .safe), gender: nil, .partner))
    }

    func testGroupsSeeOnlyEveryoneAndSafe() {
        XCTAssertFalse(shown(card(.couples, .safe), gender: .woman, .partner, group: true))
        XCTAssertFalse(shown(card(.everyone, .explicit), gender: .woman, .partner, group: true))
        XCTAssertTrue(shown(card(.everyone, .safe), gender: .woman, .partner, group: true))
    }

    func testPerspectiveFollowsWhoTheOwnerIs() {
        let mans = card(.everyone, .safe, .man)
        let womans = card(.everyone, .safe, .woman)

        XCTAssertTrue(shown(mans, gender: .woman, .friend, owner: .man))
        XCTAssertFalse(shown(womans, gender: .woman, .friend, owner: .man))
        XCTAssertFalse(shown(mans, gender: .woman, .friend, owner: .woman))
        XCTAssertTrue(shown(womans, gender: .woman, .friend, owner: .woman))
        XCTAssertFalse(shown(mans, gender: .woman, .friend, owner: nil))
        XCTAssertFalse(shown(womans, gender: .woman, .friend, owner: nil))
    }

    func testTheSqlConditionListsTheSameLabelsAsTheRule() {
        let rule = Eligibility(gender: .woman, closeness: .dating, isGroup: false, owner: .man)

        XCTAssertEqual(
            rule.sqlCondition,
            "card.audience IN ('everyone', 'women', 'couples') AND card.spice IN ('safe', 'flirty') AND card.perspective IN ('anyone', 'man')")
    }
}
