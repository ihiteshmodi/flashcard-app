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
