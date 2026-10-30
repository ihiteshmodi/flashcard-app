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
        let audience: Audience?
        let spice: Spice?
        let perspective: Perspective?
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
                        INSERT INTO card(id, deck_id, category, kind, prompt, detail, options, sort_order, is_builtin, created_at,
                                         audience, spice, perspective)
                        VALUES(?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, 1, ?9, ?10, ?11, ?12)
                        ON CONFLICT(id) DO UPDATE SET
                            deck_id = excluded.deck_id, category = excluded.category, kind = excluded.kind,
                            prompt = excluded.prompt, detail = excluded.detail, options = excluded.options,
                            sort_order = excluded.sort_order, audience = excluded.audience,
                            spice = excluded.spice, perspective = excluded.perspective
                        """,
                        [.text(card.id), .text(deck.id), .optional(card.category), .text(card.kind.rawValue),
                         .text(card.prompt), .optional(card.detail), .text(Card.encodeOptions(card.options ?? [])),
                         .number(cardIndex), .date(now),
                         .text((card.audience ?? .everyone).rawValue), .text((card.spice ?? .safe).rawValue),
                         .text((card.perspective ?? .anyone).rawValue)])
                }
                try removeRetiredCards(in: deck)
            }
        }
    }

    /// A card that left the seed (for example one split into two) disappears unless someone already
    /// asked it or answered it, so a stale combined card is not left in the stack.
    private func removeRetiredCards(in deck: SeedFile.SeedDeck) throws {
        let current = Set(deck.cards.map(\.id))
        let stored = try db.rows(
            "SELECT id FROM card WHERE deck_id = ?1 AND is_builtin = 1", [.text(deck.id)]).map { $0.string("id") }
        for id in stored where !current.contains(id) {
            try db.run(
                """
                DELETE FROM card WHERE id = ?1
                    AND NOT EXISTS (SELECT 1 FROM answer WHERE card_id = ?1)
                    AND NOT EXISTS (SELECT 1 FROM card_state WHERE card_id = ?1 AND status = 'asked')
                """, [.text(id)])
        }
    }
}
