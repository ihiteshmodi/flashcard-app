import Foundation

public enum CustomCardError: Error, LocalizedError, Equatable {
    case emptyPrompt
    case needTwoOptions
    case needAtLeastTwoOptions
    case tooManyOptions
    case builtInCard
    case unsupportedKind

    public var errorDescription: String? {
        switch self {
        case .emptyPrompt: return "Enter the question"
        case .needTwoOptions: return "Add two options"
        case .needAtLeastTwoOptions: return "Add at least two options"
        case .tooManyOptions: return "Use at most four options"
        case .builtInCard: return "Built-in cards cannot be changed"
        case .unsupportedKind: return "Pick Question, This or That or Multiple Choice"
        }
    }
}

/// The owner's own cards. They live in the "My Cards" deck and are unseen for every profile until asked.
public final class CustomCards {
    static let deckID = "my-cards"
    let db: Database
    let roles: Roles

    init(db: Database, roles: Roles) {
        self.db = db
        self.roles = roles
    }

    @discardableResult
    public func add(kind: CardKind, prompt: String, options: [String] = []) throws -> Card {
        let (text, cleanOptions) = try validated(kind: kind, prompt: prompt, options: options)
        let id = roles.newID()
        let order = (try db.firstRow("SELECT MAX(sort_order) AS top FROM card WHERE deck_id = ?1", [.text(Self.deckID)])?.optionalInt("top") ?? 0) + 1
        try db.run(
            """
            INSERT INTO card(id, deck_id, category, kind, prompt, detail, options, sort_order, is_builtin, created_at)
            VALUES(?1, ?2, NULL, ?3, ?4, NULL, ?5, ?6, 0, ?7)
            """,
            [.text(id), .text(Self.deckID), .text(kind.rawValue), .text(text),
             .text(Card.encodeOptions(cleanOptions)), .number(order), .date(roles.now())])
        return try card(id)
    }

    public func edit(_ cardID: String, prompt: String, options: [String] = []) throws {
        let existing = try ownCard(cardID)
        let (text, cleanOptions) = try validated(kind: existing.kind, prompt: prompt, options: options)
        try db.run(
            "UPDATE card SET prompt = ?2, options = ?3 WHERE id = ?1",
            [.text(cardID), .text(text), .text(Card.encodeOptions(cleanOptions))])
    }

    /// Removes the card together with every profile's mark and answer for it.
    public func delete(_ cardID: String) throws {
        _ = try ownCard(cardID)
        try db.run("DELETE FROM card WHERE id = ?1", [.text(cardID)])
    }

    public func answersLost(ifDeleting cardID: String) throws -> Int {
        try db.count("SELECT COUNT(*) AS n FROM answer WHERE card_id = ?1", [.text(cardID)])
    }

    public func cards() throws -> [Card] {
        try db.rows("SELECT * FROM card WHERE deck_id = ?1 ORDER BY sort_order", [.text(Self.deckID)]).map(Card.init(row:))
    }

    private func card(_ id: String) throws -> Card {
        guard let row = try db.firstRow("SELECT * FROM card WHERE id = ?1", [.text(id)]) else { throw DatabaseError.failed("Card not found") }
        return Card(row: row)
    }

    private func ownCard(_ id: String) throws -> Card {
        let found = try card(id)
        guard !found.isBuiltIn else { throw CustomCardError.builtInCard }
        return found
    }

    private func validated(kind: CardKind, prompt: String, options: [String]) throws -> (String, [String]) {
        let text = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw CustomCardError.emptyPrompt }
        let cleaned = options.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        switch kind {
        case .question:
            return (text, [])
        case .thisOrThat:
            guard cleaned.count == 2 else { throw CustomCardError.needTwoOptions }
            return (text, cleaned)
        case .multipleChoice:
            guard cleaned.count >= 2 else { throw CustomCardError.needAtLeastTwoOptions }
            guard cleaned.count <= 4 else { throw CustomCardError.tooManyOptions }
            return (text, cleaned)
        case .topic, .upgrade, .dare:
            throw CustomCardError.unsupportedKind
        }
    }
}
