import Foundation

public struct Answer: Equatable {
    public let text: String?
    public let pickIndex: Int?
    public let answeredBy: String?

    /// "b: Pretend you didn't notice" for multiple choice, the chosen side for this-or-that.
    public func pickLabel(for card: Card) -> String? {
        guard let pickIndex, card.options.indices.contains(pickIndex) else { return nil }
        let option = card.options[pickIndex]
        guard card.kind == .multipleChoice else { return option }
        let letter = String(UnicodeScalar(UInt8(97 + pickIndex)))
        return "\(letter): \(option)"
    }
}

public struct HistoryEntry: Identifiable, Equatable {
    public let card: Card
    public let askedAt: Date
    public let answer: Answer?
    public var id: String { card.id }
}

public final class AnswerBook {
    static let everyone = "Everyone"
    let db: Database
    let roles: Roles

    init(db: Database, roles: Roles) {
        self.db = db
        self.roles = roles
    }

    /// An empty note with no pick removes the answer. Groups label it with who answered, or "Everyone".
    public func save(profileID: String, cardID: String, text: String?, pickIndex: Int?, answeredBy: String? = nil) throws {
        let note = text?.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanNote = (note?.isEmpty ?? true) ? nil : note
        let validPick = try pickIndex.flatMap { index -> Int? in
            guard let row = try db.firstRow("SELECT * FROM card WHERE id = ?1", [.text(cardID)]) else { return nil }
            return Card(row: row).options.indices.contains(index) ? index : nil
        }
        guard cleanNote != nil || validPick != nil else {
            try db.run("DELETE FROM answer WHERE profile_id = ?1 AND card_id = ?2", [.text(profileID), .text(cardID)])
            return
        }
        let isGroup = try db.firstRow("SELECT kind FROM profile WHERE id = ?1", [.text(profileID)])?.string("kind") == "group"
        let label: String? = isGroup ? (answeredBy?.isEmpty == false ? answeredBy : Self.everyone) : nil
        try db.run(
            """
            INSERT INTO answer(profile_id, card_id, text, pick_index, answered_by, updated_at) VALUES(?1, ?2, ?3, ?4, ?5, ?6)
            ON CONFLICT(profile_id, card_id) DO UPDATE SET
                text = excluded.text, pick_index = excluded.pick_index,
                answered_by = excluded.answered_by, updated_at = excluded.updated_at
            """,
            [.text(profileID), .text(cardID), .optional(cleanNote), .optional(validPick), .optional(label), .date(roles.now())])
    }

    public func answer(profileID: String, cardID: String) throws -> Answer? {
        try db.firstRow(
            "SELECT * FROM answer WHERE profile_id = ?1 AND card_id = ?2", [.text(profileID), .text(cardID)]
        ).map(Answer.init(row:))
    }

    /// Who can be named for an answer in a group: its current members, then everyone.
    public func answerers(forGroup groupID: String) throws -> [String] {
        let names = try db.rows(
            """
            SELECT profile.name FROM group_member
            JOIN profile ON profile.id = group_member.person_id
            WHERE group_member.group_id = ?1 ORDER BY profile.name_key
            """, [.text(groupID)]).map { $0.string("name") }
        return names + [Self.everyone]
    }

    /// Asked cards, newest first. A saved answer on a card that is currently un-asked stays hidden.
    public func history(profileID: String, onlyWithAnswers: Bool = false) throws -> [HistoryEntry] {
        let rows = try db.rows(
            """
            SELECT card.*, card_state.updated_at AS asked_at,
                answer.text AS answer_text, answer.pick_index AS answer_pick, answer.answered_by AS answer_by,
                answer.card_id AS answer_card
            FROM card_state
            JOIN card ON card.id = card_state.card_id
            LEFT JOIN answer ON answer.profile_id = card_state.profile_id AND answer.card_id = card_state.card_id
            WHERE card_state.profile_id = ?1 AND card_state.status = 'asked'
            ORDER BY card_state.updated_at DESC, card_state.rowid DESC
            """, [.text(profileID)])
        let entries = rows.map { row in
            HistoryEntry(
                card: Card(row: row),
                askedAt: row.date("asked_at"),
                answer: row.optionalString("answer_card") == nil ? nil : Answer(
                    text: row.optionalString("answer_text"),
                    pickIndex: row.optionalInt("answer_pick"),
                    answeredBy: row.optionalString("answer_by")))
        }
        return onlyWithAnswers ? entries.filter { $0.answer != nil } : entries
    }
}

extension Answer {
    init(row: Row) {
        self.init(text: row.optionalString("text"), pickIndex: row.optionalInt("pick_index"), answeredBy: row.optionalString("answered_by"))
    }
}
