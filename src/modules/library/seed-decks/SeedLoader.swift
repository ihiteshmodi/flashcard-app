import Foundation

public enum SeedError: Error, LocalizedError, Equatable {
    case unreadable(String)

    public var errorDescription: String? {
        switch self {
        case .unreadable(let reason): return "The card data could not be read: \(reason)"
        }
    }
}

struct SeedFile: Decodable {
    struct SeedCard: Decodable {
        let id: String
        let category: String?
        let kind: CardKind
        let prompt: String
        let detail: String?
        let options: [String]?
    }

    struct SeedDeck: Decodable {
        let id: String
        let title: String
        let cards: [SeedCard]
    }

    let version: Int
    let decks: [SeedDeck]
}

/// Loads the bundled decks. Cards are matched by their stable id, so fixing a card's text never
/// loses the asked marks or answers that point at it.
struct SeedLoader {
    let db: Database
    let roles: Roles

    func load(_ data: Data) throws {
        let seed: SeedFile
        do {
            seed = try JSONDecoder().decode(SeedFile.self, from: data)
        } catch {
            throw SeedError.unreadable(error.localizedDescription)
        }
        let now = roles.now()
        try db.transaction {
            for (deckIndex, deck) in seed.decks.enumerated() {
                try db.run(
                    """
                    INSERT INTO deck(id, title, sort_order, is_builtin) VALUES(?1, ?2, ?3, 1)
                    ON CONFLICT(id) DO UPDATE SET title = excluded.title, sort_order = excluded.sort_order
                    """,
                    [.text(deck.id), .text(deck.title), .number(deckIndex)])
                for (cardIndex, card) in deck.cards.enumerated() {
                    try db.run(
                        """
                        INSERT INTO card(id, deck_id, category, kind, prompt, detail, options, sort_order, is_builtin, created_at)
                        VALUES(?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, 1, ?9)
                        ON CONFLICT(id) DO UPDATE SET
                            deck_id = excluded.deck_id, category = excluded.category, kind = excluded.kind,
                            prompt = excluded.prompt, detail = excluded.detail, options = excluded.options,
                            sort_order = excluded.sort_order
                        """,
                        [.text(card.id), .text(deck.id), .optional(card.category), .text(card.kind.rawValue),
                         .text(card.prompt), .optional(card.detail), .text(Card.encodeOptions(card.options ?? [])),
                         .number(cardIndex), .date(now)])
                }
            }
        }
    }
}
