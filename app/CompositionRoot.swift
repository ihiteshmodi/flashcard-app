import FlashcardsCore
import Foundation

/// The only place that picks file paths, launch arguments and the live roles.
enum CompositionRoot {
    static func start() -> Result<Flashcards, Error> {
        Result {
            let database = try openDatabase()
            return try Flashcards(database: database, roles: .live)
        }
    }

    private static func openDatabase() throws -> Database {
        if ProcessInfo.processInfo.arguments.contains("-UITestInMemory") {
            return try Database.inMemory()
        }
        let folder = try FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        return try Database(path: folder.appendingPathComponent("flashcards.sqlite").path)
    }
}
