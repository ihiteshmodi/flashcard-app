import Foundation

/// The application interface: one place that exposes every use case to the app and the tests.
public final class Flashcards {
    public let database: Database
    public let profiles: Profiles

    public init(database: Database, roles: Roles = .live) throws {
        try Migrator.current.migrate(database)
        self.database = database
        profiles = Profiles(db: database, roles: roles)
    }
}
