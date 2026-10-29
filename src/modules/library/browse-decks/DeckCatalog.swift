import Foundation

public struct DeckSummary: Identifiable, Equatable {
    public let deck: Deck
    public let cardCount: Int
    public let categories: [String]
    public var id: String { deck.id }
}

/// Read-only browsing of the bundled decks. The owner's own cards are managed in `CustomCards`.
public final class DeckCatalog {
    let db: Database

    init(db: Database) { self.db = db }

    public func decks() throws -> [DeckSummary] {
        let rows = try db.rows(
            """
            SELECT deck.*, (SELECT COUNT(*) FROM card WHERE card.deck_id = deck.id) AS card_count
            FROM deck WHERE deck.is_builtin = 1 ORDER BY deck.sort_order
            """)
        return try rows.filter { $0.int("card_count") > 0 }.map { row in
            let categories = try db.rows(
                "SELECT category FROM card WHERE deck_id = ?1 AND category IS NOT NULL GROUP BY category ORDER BY MIN(sort_order)",
                [.text(row.string("id"))]).map { $0.string("category") }
            return DeckSummary(deck: Deck(row: row), cardCount: row.int("card_count"), categories: categories)
        }
    }

    public func cards(in deckID: String) throws -> [Card] {
        try db.rows("SELECT * FROM card WHERE deck_id = ?1 ORDER BY sort_order", [.text(deckID)]).map(Card.init(row:))
    }
}
