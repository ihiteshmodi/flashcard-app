import Foundation
import Observation

@Observable
public final class CardSession {
    private enum Swipe {
        case asked
        case skipped
    }

    private struct Move {
        let card: Card
        let swipe: Swipe
        let previous: CardStatus?
    }

    public let profileID: String
    @ObservationIgnored private let db: Database
    @ObservationIgnored private let roles: Roles
    public private(set) var stack: [Card] = []
    public private(set) var progress = Progress(asked: 0, total: 0)
    private var undoMoves: [Move] = []
    private var redoMoves: [Move] = []

    init(profileID: String, db: Database, roles: Roles) throws {
        self.profileID = profileID
        self.db = db
        self.roles = roles
        try syncWithLibrary()
    }

    public var topCard: Card? { stack.first }
    public var isAllAsked: Bool { stack.isEmpty && progress.total > 0 }
    public var hasNoCards: Bool { progress.total == 0 }
    public var canUndo: Bool { !undoMoves.isEmpty }
    public var canRedo: Bool { !redoMoves.isEmpty }

    /// Marks the top card asked and returns it, so the caller can offer the note sheet.
    @discardableResult
    public func swipeRight() throws -> Card? {
        redoMoves.removeAll()
        return try apply(.asked)
    }

    /// Skips the top card; it goes to the end of the stack and stays unasked.
    public func swipeLeft() throws {
        redoMoves.removeAll()
        try apply(.skipped)
    }

    public func undo() throws {
        guard let move = undoMoves.popLast() else { return }
        try CardStates.set(db, profileID: profileID, cardID: move.card.id, status: move.previous, at: roles.now())
        stack.removeAll { $0.id == move.card.id }
        stack.insert(move.card, at: 0)
        redoMoves.append(move)
        progress = try CardStates.progress(db, profileID: profileID)
    }

    public func redo() throws {
        guard let move = redoMoves.popLast() else { return }
        try apply(move.swipe)
    }

    /// Clears the asked and skipped marks for this profile. Saved answers stay.
    public func startOver() throws {
        try CardStates.clearAll(db, profileID: profileID)
        undoMoves.removeAll()
        redoMoves.removeAll()
        stack = []
        try syncWithLibrary()
    }

    /// Picks up deck changes and new cards without losing the current order or undo history.
    public func syncWithLibrary() throws {
        let fresh = try loadStack()
        let freshIDs = Set(fresh.map(\.id))
        let kept = stack.filter { freshIDs.contains($0.id) }
        let keptIDs = Set(kept.map(\.id))
        stack = kept + fresh.filter { !keptIDs.contains($0.id) }
        let existing = Set(try db.rows("SELECT id FROM card").map { $0.string("id") })
        undoMoves.removeAll { !existing.contains($0.card.id) }
        redoMoves.removeAll { !existing.contains($0.card.id) }
        progress = try CardStates.progress(db, profileID: profileID)
    }

    @discardableResult
    private func apply(_ swipe: Swipe) throws -> Card? {
        guard let card = stack.first else { return nil }
        let previous = try CardStates.status(db, profileID: profileID, cardID: card.id)
        try CardStates.set(
            db, profileID: profileID, cardID: card.id,
            status: swipe == .asked ? .asked : .skipped, at: roles.now())
        stack.removeFirst()
        if swipe == .skipped { stack.append(card) }
        undoMoves.append(Move(card: card, swipe: swipe, previous: previous))
        progress = try CardStates.progress(db, profileID: profileID)
        return card
    }

    /// Unseen cards in shuffled order, then skipped cards oldest skip first.
    private func loadStack() throws -> [Card] {
        let rows = try db.rows(
            """
            SELECT card.*, s.status AS state_status, s.updated_at AS state_at
            FROM card
            JOIN deck ON deck.id = card.deck_id
            LEFT JOIN card_state s ON s.card_id = card.id AND s.profile_id = ?1
            WHERE \(try CardStates.visibleCards(db, profileID: profileID)) AND (s.status IS NULL OR s.status = 'skipped')
            ORDER BY deck.sort_order, card.sort_order
            """, [.text(profileID)])
        let unseen = rows.filter { $0.optionalString("state_status") == nil }
        let skipped = rows
            .filter { $0.optionalString("state_status") == "skipped" }
            .sorted { $0.date("state_at") < $1.date("state_at") }
        let byID = Dictionary(uniqueKeysWithValues: unseen.map { ($0.string("id"), $0) })
        let shuffled = roles.shuffle(unseen.map { $0.string("id") }).compactMap { byID[$0] }
        return (shuffled + skipped).map(Card.init(row:))
    }
}
