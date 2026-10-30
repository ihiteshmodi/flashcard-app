import Foundation

public enum CustomCardError: Error, LocalizedError, Equatable {
    case emptyPrompt
    case needTwoOptions
    case needAtLeastTwoOptions
    case tooManyOptions
    case builtInCard
    case unsupportedKind
    case unknownDeck

    public var errorDescription: String? {
        switch self {
        case .emptyPrompt: return "Enter the question"
        case .needTwoOptions: return "Add two options"
        case .needAtLeastTwoOptions: return "Add at least two options"
        case .tooManyOptions: return "Use at most four options"
        case .builtInCard: return "Built-in cards cannot be changed"
        case .unsupportedKind: return "Pick Question, This or That, Multiple Choice or Dare"
        case .unknownDeck: return "Choose a deck"
        }
    }
}

/// The owner's own cards. They default to the "My Cards" deck but can join any deck, and carry the same labels as bundled cards.
public final class CustomCards {
    public static let deckID = "my-cards"
    let db: Database
    let roles: Roles

    init(db: Database, roles: Roles) {
        self.db = db
        self.roles = roles
    }

    @discardableResult
    public func add(
        kind: CardKind, prompt: String, options: [String] = [],
        deckID: String = CustomCards.deckID, category: String? = nil, detail: String? = nil,
        audience: Audience = .everyone, spice: Spice = .safe, perspective: Perspective = .anyone
    ) throws -> Card {
        let (text, cleanOptions) = try validated(kind: kind, prompt: prompt, options: options)
        try requireDeck(deckID)
        let id = roles.newID()
        let order = (try db.firstRow("SELECT MAX(sort_order) AS top FROM card WHERE deck_id = ?1", [.text(deckID)])?.optionalInt("top") ?? 0) + 1
        try db.run(
            """
            INSERT INTO card(id, deck_id, category, kind, prompt, detail, options, sort_order, is_builtin, created_at,
                             audience, spice, perspective)
            VALUES(?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, 0, ?9, ?10, ?11, ?12)
            """,
            [.text(id), .text(deckID), .optional(trimmedOrNil(category)), .text(kind.rawValue), .text(text),
             .optional(trimmedOrNil(detail)), .text(Card.encodeOptions(cleanOptions)), .number(order), .date(roles.now()),
             .text(audience.rawValue), .text(spice.rawValue), .text(perspective.rawValue)])
        return try card(id)
    }

    /// Replaces the text, options and labels. The kind stays; the deck stays unless a new one is given.
    public func edit(
        _ cardID: String, prompt: String, options: [String] = [],
        deckID: String? = nil, category: String? = nil, detail: String? = nil,
        audience: Audience = .everyone, spice: Spice = .safe, perspective: Perspective = .anyone
    ) throws {
        let existing = try ownCard(cardID)
        let (text, cleanOptions) = try validated(kind: existing.kind, prompt: prompt, options: options)
        let targetDeck = deckID ?? existing.deckID
        try requireDeck(targetDeck)
        try db.run(
            """
            UPDATE card SET prompt = ?2, options = ?3, deck_id = ?4, category = ?5, detail = ?6,
                audience = ?7, spice = ?8, perspective = ?9
            WHERE id = ?1
            """,
            [.text(cardID), .text(text), .text(Card.encodeOptions(cleanOptions)), .text(targetDeck),
             .optional(trimmedOrNil(category)), .optional(trimmedOrNil(detail)),
             .text(audience.rawValue), .text(spice.rawValue), .text(perspective.rawValue)])
    }

    /// Removes the card together with every profile's mark and answer for it.
    public func delete(_ cardID: String) throws {
        _ = try ownCard(cardID)
        try db.run("DELETE FROM card WHERE id = ?1", [.text(cardID)])
    }

    public func answersLost(ifDeleting cardID: String) throws -> Int {
        try db.count("SELECT COUNT(*) AS n FROM answer WHERE card_id = ?1", [.text(cardID)])
    }

    /// Every card the owner created, in any deck.
    public func cards() throws -> [Card] {
        try db.rows(
            """
            SELECT card.* FROM card JOIN deck ON deck.id = card.deck_id
            WHERE card.is_builtin = 0 ORDER BY deck.sort_order, card.sort_order
            """).map(Card.init(row:))
    }

    /// Categories already used in a deck, for the picker in the card editor.
    public func categories(inDeck deckID: String) throws -> [String] {
        try db.rows(
            "SELECT DISTINCT category FROM card WHERE deck_id = ?1 AND category IS NOT NULL ORDER BY category",
            [.text(deckID)]).map { $0.string("category") }
    }

    private func requireDeck(_ id: String) throws {
        guard try db.firstRow("SELECT 1 AS found FROM deck WHERE id = ?1", [.text(id)]) != nil else {
            throw CustomCardError.unknownDeck
        }
    }

    private func trimmedOrNil(_ text: String?) -> String? {
        guard let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else { return nil }
        return trimmed
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
        case .dare:
            return (text, [])
        case .topic, .upgrade:
            throw CustomCardError.unsupportedKind
        }
    }
}
