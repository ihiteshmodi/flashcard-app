import Foundation

public struct SavedGameSetup: Equatable, Codable {
    public let groupID: String?
    public let personIDs: [String]
    public let includeMe: Bool
    public let sets: Set<String>

    public init(groupID: String? = nil, personIDs: [String] = [], includeMe: Bool = false, sets: Set<String>) {
        self.groupID = groupID
        self.personIDs = personIDs
        self.includeMe = includeMe
        self.sets = sets
    }
}

/// A game on the table: every move is applied to a copy, kept, and only then becomes the game, so a refused move
/// or a failed save changes nothing and closing the app never loses a move.
public final class GameTable {
    static let settingKey = "game.current"

    public private(set) var game: Game
    private let db: Database
    private let library: GameCardLibrary
    private let history: GameHistory
    private let roles: Roles

    init(game: Game, db: Database, library: GameCardLibrary, history: GameHistory, roles: Roles) {
        self.game = game
        self.db = db
        self.library = library
        self.history = history
        self.roles = roles
    }

    public func ready() throws { try apply { try $0.ready() } }

    public func submit(_ cardIDs: [String]) throws {
        try apply(
            change: { try $0.submit(cardIDs) },
            persist: { [history] updated in
                if case .reveal(let answers) = updated.phase {
                    try history.record(blackCard: updated.blackCard, answers: answers, targetGroupID: updated.targetGroupID)
                }
            })
    }

    public func nextRound() throws {
        try apply { [roles] in try $0.nextRound(shuffle: roles.shuffle) }
    }

    public func resetAndContinue() throws {
        let targets = GameHistory.targetProfileIDs(targetGroupID: game.targetGroupID, players: game.players)
        try apply(
            change: { [library, roles] in try $0.resetAndContinue(library: library, shuffle: roles.shuffle) },
            persist: { [history] _ in try history.resetAsked(forProfiles: targets) })
    }

    public func end() throws {
        try db.setSetting(Self.settingKey, nil)
    }

    func save() throws {
        try db.setSetting(Self.settingKey, String(decoding: try JSONEncoder().encode(game), as: UTF8.self))
    }

    private func apply(change: (inout Game) throws -> Void, persist: ((Game) throws -> Void)? = nil) throws {
        var next = game
        try change(&next)
        let previous = game
        do {
            try db.transaction {
                try persist?(next)
                game = next
                try save()
            }
        } catch {
            game = previous
            throw error
        }
    }

    static func resume(from db: Database, library: GameCardLibrary, history: GameHistory, roles: Roles) throws -> GameTable? {
        guard let saved = try db.setting(settingKey) else { return nil }
        guard let game = try? JSONDecoder().decode(Game.self, from: Data(saved.utf8)) else {
            try db.setSetting(settingKey, nil)
            return nil
        }
        return GameTable(game: game, db: db, library: library, history: history, roles: roles)
    }
}
