import Foundation

/// The application interface: one place that exposes every use case to the app and the tests.
public final class Flashcards {
    public let database: Database
    public let profiles: Profiles
    public let decks: DeckChoices
    public let catalog: DeckCatalog
    public let groups: Groups
    public let answers: AnswerBook
    public let customCards: CustomCards
    public let backup: Backup
    private let seedLoader: SeedLoader
    private let roles: Roles
    private var seedData: Data?
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
        seedLoader = SeedLoader(db: database, roles: roles)
        var reload: () throws -> Void = {}
        backup = Backup(db: database, roles: roles, safetyFolder: safetyCopyFolder, afterRestore: { try reload() })
        reload = { [weak self] in
            guard let self else { return }
            self.sessions.removeAll()
            if let data = self.seedData { try self.seedLoader.load(data) }
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
        seedData = data
    }
}
