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
    public let gameHistory: GameHistory
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
        gameHistory = GameHistory(db: database, roles: roles)
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

    /// Starts a game from existing people or a group, skipping already-asked black cards, and keeps it.
    public func startGame(
        groupID: String? = nil,
        personIDs: [String] = [],
        includeMe: Bool = false,
        sets: Set<String>
    ) throws -> GameTable {
        var players: [GamePlayer] = includeMe ? [.me] : []
        if let groupID {
            let members = try groups.members(of: groupID)
            players.append(contentsOf: members.map(GamePlayer.init(profile:)))
        } else {
            for id in personIDs {
                if let profile = try profiles.profile(id), profile.kind == .person {
                    players.append(GamePlayer(profile: profile))
                }
            }
        }
        let targets = GameHistory.targetProfileIDs(targetGroupID: groupID, players: players)
        let excluded = try gameHistory.askedBlackCardIDs(forProfiles: targets)
        let game = try Game.start(
            players: players,
            targetGroupID: groupID,
            library: gameCards,
            sets: sets,
            excludedBlackIDs: excluded,
            shuffle: roles.shuffle)
        let table = GameTable(game: game, db: database, library: gameCards, history: gameHistory, roles: roles)
        let setup = SavedGameSetup(groupID: groupID, personIDs: personIDs, includeMe: includeMe, sets: sets)
        try database.transaction {
            try table.save()
            try database.setSetting("game.setup", String(decoding: try JSONEncoder().encode(setup), as: UTF8.self))
        }
        return table
    }

    public func resetAskedGameCards(groupID: String? = nil, personIDs: [String] = []) throws {
        let targets = groupID.map { [$0] } ?? personIDs
        try gameHistory.resetAsked(forProfiles: targets)
    }

    public func lastGameSetup() throws -> SavedGameSetup? {
        guard let saved = try database.setting("game.setup") else { return nil }
        return try? JSONDecoder().decode(SavedGameSetup.self, from: Data(saved.utf8))
    }

    /// The game that was in progress when the app was last closed, if any.
    public func resumeGame() throws -> GameTable? {
        try GameTable.resume(from: database, library: gameCards, history: gameHistory, roles: roles)
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
