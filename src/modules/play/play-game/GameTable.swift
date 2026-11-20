import Foundation

/// A game on the table: every move is applied to a copy, kept, and only then becomes the game, so a refused move
/// or a failed save changes nothing and closing the app never loses a move.
public final class GameTable {
    static let settingKey = "game.current"

    public private(set) var game: Game
    private let db: Database
    private let roles: Roles

    init(game: Game, db: Database, roles: Roles) {
        self.game = game
        self.db = db
        self.roles = roles
    }

    public func ready() throws { try apply { try $0.ready() } }
    public func play(_ cardIDs: [String]) throws { try apply { try $0.play(cardIDs) } }
    public func choose(playAt index: Int) throws { try apply { try $0.choose(playAt: index) } }
    public func nextRound() throws { try apply { [roles] in try $0.nextRound(shuffle: roles.shuffle) } }

    /// There is no winner to declare: ending the game shows the scores and forgets the game.
    public func end() throws -> [Game.ScoreLine] {
        try db.setSetting(Self.settingKey, nil)
        return game.scoreboard
    }

    func save() throws {
        try db.setSetting(Self.settingKey, String(decoding: try JSONEncoder().encode(game), as: UTF8.self))
    }

    private func apply(_ change: (inout Game) throws -> Void) throws {
        var next = game
        try change(&next)
        let previous = game
        game = next
        do { try save() } catch {
            game = previous
            throw error
        }
    }

    static func resume(from db: Database, roles: Roles) throws -> GameTable? {
        guard let saved = try db.setting(settingKey) else { return nil }
        guard let game = try? JSONDecoder().decode(Game.self, from: Data(saved.utf8)) else {
            try db.setSetting(settingKey, nil)
            return nil
        }
        return GameTable(game: game, db: db, roles: roles)
    }
}
