import Foundation

public struct RecordedPick: Equatable, Codable {
    public let playerID: String
    public let playerName: String
    public let playerEmoji: String
    public let cards: [String]

    public init(playerID: String, playerName: String, playerEmoji: String, cards: [String]) {
        self.playerID = playerID
        self.playerName = playerName
        self.playerEmoji = playerEmoji
        self.cards = cards
    }
}

public struct GameRoundEntry: Identifiable, Equatable {
    public let id: String
    public let profileID: String
    public let blackCardID: String
    public let prompt: String
    public let picks: [RecordedPick]
    public let playedAt: Date

    /// Groups list everyone's named pick; a person's own profile shows what that person picked.
    public func answerLines(for profile: Profile) -> [String] {
        if profile.kind == .group {
            return picks.map { "\($0.playerName): \($0.cards.joined(separator: " / "))" }
        }
        if let mine = picks.first(where: { $0.playerID == profile.id }) {
            return [mine.cards.joined(separator: " / ")]
        }
        return picks.map { "\($0.playerName): \($0.cards.joined(separator: " / "))" }
    }
}

public final class GameHistory {
    let db: Database
    let roles: Roles

    init(db: Database, roles: Roles) {
        self.db = db
        self.roles = roles
    }

    public func history(profileID: String) throws -> [GameRoundEntry] {
        let rows = try db.rows(
            "SELECT * FROM game_round WHERE profile_id = ?1 ORDER BY played_at DESC, rowid DESC",
            [.text(profileID)])
        return rows.map { row in
            let picks = (try? JSONDecoder().decode([RecordedPick].self, from: Data(row.string("answers_json").utf8))) ?? []
            return GameRoundEntry(
                id: row.string("id"),
                profileID: row.string("profile_id"),
                blackCardID: row.string("black_card_id"),
                prompt: row.string("prompt"),
                picks: picks,
                playedAt: row.date("played_at"))
        }
    }

    public func askedBlackCardIDs(forProfiles profileIDs: [String]) throws -> Set<String> {
        var ids = Set<String>()
        for profileID in Set(profileIDs) {
            let rows = try db.rows(
                "SELECT DISTINCT black_card_id FROM game_round WHERE profile_id = ?1 AND is_asked = 1",
                [.text(profileID)])
            for row in rows { ids.insert(row.string("black_card_id")) }
        }
        return ids
    }

    /// Clears asked marks so black cards can be played again, while keeping every History entry intact.
    public func resetAsked(forProfiles profileIDs: [String]) throws {
        try db.transaction {
            for profileID in Set(profileIDs) {
                try db.run("UPDATE game_round SET is_asked = 0 WHERE profile_id = ?1", [.text(profileID)])
            }
        }
    }

    func record(blackCard: BlackCard, answers: [Game.PlayerAnswer], targetGroupID: String?) throws {
        let targets = Self.targetProfileIDs(targetGroupID: targetGroupID, players: answers.map(\.player))
        guard !targets.isEmpty else { return }
        let recorded = answers.map {
            RecordedPick(
                playerID: $0.player.id,
                playerName: $0.player.name,
                playerEmoji: $0.player.emoji,
                cards: $0.cards.map(\.text))
        }
        let encoded = String(decoding: try JSONEncoder().encode(recorded), as: UTF8.self)
        let now = roles.now()
        for profileID in targets {
            try db.run(
                """
                INSERT INTO game_round(id, profile_id, black_card_id, prompt, answers_json, is_asked, played_at)
                VALUES(?1, ?2, ?3, ?4, ?5, 1, ?6)
                """,
                [.text(roles.newID()), .text(profileID), .text(blackCard.id), .text(blackCard.text), .text(encoded), .date(now)])
        }
    }

    static func targetProfileIDs(targetGroupID: String?, players: [GamePlayer]) -> [String] {
        if let targetGroupID { return [targetGroupID] }
        var seen = Set<String>()
        return players.compactMap(\.profileID).filter { seen.insert($0).inserted }
    }
}
