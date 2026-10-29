import Foundation

public enum DeckChoiceError: Error, LocalizedError, Equatable {
    case keepOneDeckOn

    public var errorDescription: String? { "Keep at least one deck on" }
}

public struct DeckRow: Identifiable, Equatable {
    public let deck: Deck
    public let isOn: Bool
    public let askedCount: Int
    public let cardCount: Int
    public var id: String { deck.id }
}

public final class DeckChoices {
    let db: Database

    init(db: Database) { self.db = db }

    /// Only decks that hold cards are listed, so an empty "My Cards" stays out of the way.
    public func rows(for profileID: String) throws -> [DeckRow] {
        let rows = try db.rows(
            """
            SELECT deck.*,
                (SELECT COUNT(*) FROM card WHERE card.deck_id = deck.id) AS card_count,
                (SELECT COUNT(*) FROM card_state JOIN card ON card.id = card_state.card_id
                    WHERE card.deck_id = deck.id AND card_state.profile_id = ?1 AND card_state.status = 'asked') AS asked_count,
                EXISTS(SELECT 1 FROM profile_deck_off WHERE profile_id = ?1 AND deck_id = deck.id) AS is_off
            FROM deck
            WHERE card_count > 0
            ORDER BY deck.sort_order
            """, [.text(profileID)])
        return rows.map {
            DeckRow(deck: Deck(row: $0), isOn: !$0.bool("is_off"), askedCount: $0.int("asked_count"), cardCount: $0.int("card_count"))
        }
    }

    public func setDeck(_ deckID: String, on: Bool, for profileID: String) throws {
        if on {
            try db.run("DELETE FROM profile_deck_off WHERE profile_id = ?1 AND deck_id = ?2", [.text(profileID), .text(deckID)])
            return
        }
        let othersOn = try rows(for: profileID).filter { $0.isOn && $0.id != deckID }
        guard !othersOn.isEmpty else { throw DeckChoiceError.keepOneDeckOn }
        try db.run(
            "INSERT OR IGNORE INTO profile_deck_off(profile_id, deck_id) VALUES(?1, ?2)",
            [.text(profileID), .text(deckID)])
    }
}
