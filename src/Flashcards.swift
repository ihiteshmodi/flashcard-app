import Foundation

/// The application interface: one place that exposes every use case to the app and the tests.
public final class Flashcards {
    public let database: Database
    public let profiles: Profiles
    public let decks: DeckChoices
    private let seedLoader: SeedLoader

    public init(database: Database, roles: Roles = .live) throws {
        try Migrator.current.migrate(database)
        self.database = database
        profiles = Profiles(db: database, roles: roles)
        decks = DeckChoices(db: database)
        seedLoader = SeedLoader(db: database, roles: roles)
    }

    /// Adds or updates the bundled decks from the seed JSON.
    public func loadSeed(_ data: Data) throws {
        try seedLoader.load(data)
    }
}
