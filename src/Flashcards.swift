import Foundation

public final class Flashcards {
    public let database: Database
    public let profiles: Profiles
    public let decks: DeckChoices
    public let catalog: DeckCatalog
    public let groups: Groups
    public let answers: AnswerBook
    public let customCards: CustomCards
    public let owner: Owner
    public let backup: Backup
    public private(set) var gameCards: GameCardLibrary
    private let seedLoader: SeedLoader
    private let roles: Roles
    private var seeds: [Data] = []
    private var sessions: [String: CardSession] = [:]

    public init(database: Database, roles: Roles = .live, safetyCopyFolder: URL? = nil) throws {
        try Migrator.current.migrate(database)
        self.database = database
        self.roles = roles
        profiles = Profiles(db: database, roles: roles)
        decks = DeckChoices(db: database)
        catalog = DeckCatalog(db: database)
        groups = Groups(db: database, profiles: profiles)
        answers = AnswerBook(db: database, roles: roles)
        customCards = CustomCards(db: database, roles: roles)
        owner = Owner(db: database)
        gameCards = try GameCardLibrary(files: [])
        seedLoader = SeedLoader(db: database, roles: roles)
        var reload: () throws -> Void = {}
        backup = Backup(db: database, roles: roles, safetyFolder: safetyCopyFolder, afterRestore: { try reload() })
        reload = { [weak self] in
            guard let self else { return }
            self.sessions.removeAll()
            for data in self.seeds { try self.seedLoader.load(data) }
        }
    }

    /// One session per profile, kept so undo and redo survive switching profiles.
    public func session(for profileID: String) throws -> CardSession {
        if let existing = sessions[profileID] { return existing }
        let created = try CardSession(profileID: profileID, db: database, roles: roles)
        sessions[profileID] = created
        return created
    }

    /// Adds or updates the bundled decks from the seed JSON, and again after an import.
    public func loadSeed(_ data: Data) throws {
        try seedLoader.load(data)
        seeds.append(data)
    }

    /// The bundled game cards, the public set first and then any private file; each file adds its sets.
    public func loadGameCards(_ files: [Data]) throws {
        gameCards = try GameCardLibrary(files: files)
    }

    /// Starts a game on the loaded cards and keeps it, replacing any game in progress.
    public func startGame(players: [String], sets: Set<String>) throws -> GameTable {
        let game = try Game.start(players: players, library: gameCards, sets: sets, shuffle: roles.shuffle)
        let table = GameTable(game: game, db: database, roles: roles)
        try table.save()
        let setup = GameSetup(players: game.players, sets: sets.sorted())
        try database.setSetting("game.setup", String(decoding: try JSONEncoder().encode(setup), as: UTF8.self))
        return table
    }

    /// The players and card sets of the last game that started, so the next one does not start from empty.
    public func lastGameSetup() throws -> (players: [String], sets: Set<String>)? {
        guard let saved = try database.setting("game.setup"),
              let setup = try? JSONDecoder().decode(GameSetup.self, from: Data(saved.utf8)) else { return nil }
        return (setup.players, Set(setup.sets))
    }

    /// The game that was in progress when the app was last closed, if any.
    public func resumeGame() throws -> GameTable? {
        try GameTable.resume(from: database, roles: roles)
    }

    public func setGender(of profileID: String, to gender: Gender?) throws {
        try profiles.setGender(profileID, to: gender)
        try syncSessions()
    }

    public func setCloseness(of profileID: String, to closeness: Closeness) throws {
        try profiles.setCloseness(profileID, to: closeness)
        try syncSessions()
    }

    public func setOwnerGender(_ gender: Gender?) throws {
        try owner.setGender(gender)
        try syncSessions()
    }

    private func syncSessions() throws {
        for session in sessions.values { try session.syncWithLibrary() }
    }
}

private struct GameSetup: Codable {
    let players: [String]
    let sets: [String]
}
