import Foundation

enum CardStatus: String {
    case asked
    case skipped
}

public struct Progress: Equatable {
    public let asked: Int
    public let total: Int
    public var left: Int { total - asked }
}

/// Per-profile card state: no row means unseen.
enum CardStates {
    static let enabledDecks = "card.deck_id NOT IN (SELECT deck_id FROM profile_deck_off WHERE profile_id = ?1)"
    static let ownerGenderKey = "owner_gender"

    static func eligibility(_ db: Database, profileID: String) throws -> Eligibility {
        let row = try db.firstRow("SELECT kind, gender, closeness FROM profile WHERE id = ?1", [.text(profileID)])
        let owner = try db.setting(ownerGenderKey).flatMap(Gender.init(rawValue:))
        return Eligibility(
            gender: row?.optionalString("gender").flatMap(Gender.init(rawValue:)),
            closeness: row.flatMap { Closeness(rawValue: $0.string("closeness")) } ?? .friend,
            isGroup: row?.string("kind") == ProfileKind.group.rawValue,
            owner: owner)
    }

    /// Cards in the decks that are switched on and that the profile's labels allow, for `?1` = the profile id.
    static func visibleCards(_ db: Database, profileID: String) throws -> String {
        "\(enabledDecks) AND \(try eligibility(db, profileID: profileID).sqlCondition)"
    }

    static func progress(_ db: Database, profileID: String) throws -> Progress {
        let visible = try visibleCards(db, profileID: profileID)
        let total = try db.count(
            "SELECT COUNT(*) AS n FROM card WHERE \(visible)", [.text(profileID)])
        let asked = try db.count(
            """
            SELECT COUNT(*) AS n FROM card_state
            JOIN card ON card.id = card_state.card_id
            WHERE card_state.profile_id = ?1 AND card_state.status = 'asked' AND \(visible)
            """, [.text(profileID)])
        return Progress(asked: asked, total: total)
    }

    static func status(_ db: Database, profileID: String, cardID: String) throws -> CardStatus? {
        let row = try db.firstRow(
            "SELECT status FROM card_state WHERE profile_id = ?1 AND card_id = ?2",
            [.text(profileID), .text(cardID)])
        return row.flatMap { CardStatus(rawValue: $0.string("status")) }
    }

    static func set(_ db: Database, profileID: String, cardID: String, status: CardStatus?, at date: Date) throws {
        guard let status else {
            try db.run("DELETE FROM card_state WHERE profile_id = ?1 AND card_id = ?2", [.text(profileID), .text(cardID)])
            return
        }
        try db.run(
            """
            INSERT INTO card_state(profile_id, card_id, status, updated_at) VALUES(?1, ?2, ?3, ?4)
            ON CONFLICT(profile_id, card_id) DO UPDATE SET status = excluded.status, updated_at = excluded.updated_at
            """,
            [.text(profileID), .text(cardID), .text(status.rawValue), .date(date)])
    }

    static func clearAll(_ db: Database, profileID: String) throws {
        try db.run("DELETE FROM card_state WHERE profile_id = ?1", [.text(profileID)])
    }
}
