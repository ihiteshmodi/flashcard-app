import FlashcardsCore
import Foundation

/// The only place that picks file paths, launch arguments and the live roles.
enum CompositionRoot {
    static func start() -> Result<Flashcards, Error> {
        Result {
            let arguments = ProcessInfo.processInfo.arguments
            let isUITest = arguments.contains("-UITestInMemory")
            let database = isUITest ? try Database.inMemory() : try openDatabase()
            let roles = isUITest
                ? Roles(now: { Date() }, shuffle: { $0 }, newID: { UUID().uuidString })
                : Roles.live
            let app = try Flashcards(database: database, roles: roles, safetyCopyFolder: try safetyCopyFolder())
            // The public starter deck first, then the owner's private decks; shared ids update in place.
            let deckFiles = arguments.contains("-UITestDemoData") ? ["DemoDecks"] : ["StarterDecks", "seed"]
            for name in deckFiles {
                if let url = Bundle.main.url(forResource: name, withExtension: "json") {
                    try app.loadSeed(Data(contentsOf: url))
                }
            }
            return app
        }
    }

    private static func openDatabase() throws -> Database {
        let folder = try FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        return try Database(path: folder.appendingPathComponent("flashcards.sqlite").path)
    }

    /// Visible in Files under "On My iPhone" so safety copies can be fetched or kept.
    private static func safetyCopyFolder() throws -> URL {
        try FileManager.default
            .url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("Safety Copies")
    }
}
