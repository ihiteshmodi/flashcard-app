import Foundation

public enum BackupError: Error, LocalizedError, Equatable {
    case notABackup
    case newerVersion
    case unreadable(String)

    public var errorDescription: String? {
        switch self {
        case .notABackup: return "This file is not a Flashcards backup"
        case .newerVersion: return "This backup is from a newer version of the app. Update the app first."
        case .unreadable(let reason): return "The file could not be read: \(reason)"
        }
    }
}

public struct BackupInfo: Equatable {
    public let schemaVersion: Int
    public let profileCount: Int
    public let answerCount: Int
}

public final class Backup {
    private static let lastExportKey = "last_export_at"
    private static let requiredTables: Set<String> = [
        "deck", "card", "profile", "group_member", "profile_deck_off", "card_state", "answer", "setting",
    ]

    let db: Database
    let roles: Roles
    let migrator: Migrator
    let safetyFolder: URL?
    let afterRestore: () throws -> Void

    init(db: Database, roles: Roles, migrator: Migrator = .current, safetyFolder: URL?, afterRestore: @escaping () throws -> Void) {
        self.db = db
        self.roles = roles
        self.migrator = migrator
        self.safetyFolder = safetyFolder
        self.afterRestore = afterRestore
    }

    public func suggestedFileName(timeZone: TimeZone = .current) -> String {
        "flashcards-\(Self.dayStamp(roles.now(), timeZone: timeZone)).sqlite"
    }

    public var lastExportedAt: Date? {
        guard let text = try? db.setting(Self.lastExportKey), let seconds = Double(text) else { return nil }
        return Date(timeIntervalSince1970: seconds)
    }

    public func export(to url: URL) throws {
        if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
        try db.run("VACUUM INTO ?1", [.text(url.path)])
        try db.setSetting(Self.lastExportKey, String(roles.now().timeIntervalSince1970))
    }

    public func inspect(_ url: URL) throws -> BackupInfo {
        guard FileManager.default.fileExists(atPath: url.path) else { throw BackupError.unreadable("the file is missing") }
        let source: Database
        do { source = try Database(path: url.path, readOnly: true) } catch { throw BackupError.notABackup }
        let tables: Set<String>
        let version: Int
        do {
            tables = try source.tableNames()
            version = try source.schemaVersion()
        } catch {
            throw BackupError.notABackup
        }
        guard Self.requiredTables.isSubset(of: tables) else { throw BackupError.notABackup }
        guard version <= migrator.latestVersion else { throw BackupError.newerVersion }
        return BackupInfo(
            schemaVersion: version,
            profileCount: try source.count("SELECT COUNT(*) AS n FROM profile"),
            answerCount: try source.count("SELECT COUNT(*) AS n FROM answer"))
    }

    /// Replaces all current data with the backup, after keeping a safety copy of what is there now.
    @discardableResult
    public func restore(from url: URL) throws -> URL? {
        _ = try inspect(url)
        let safetyCopy = try keepSafetyCopy()
        let source = try Database(path: url.path, readOnly: true)
        try db.replaceContents(with: source)
        try migrator.migrate(db)
        try afterRestore()
        return safetyCopy
    }

    private func keepSafetyCopy() throws -> URL? {
        guard let safetyFolder else { return nil }
        try FileManager.default.createDirectory(at: safetyFolder, withIntermediateDirectories: true)
        let name = "flashcards-before-import-\(Self.dayStamp(roles.now(), timeZone: .current))-\(Int(roles.now().timeIntervalSince1970)).sqlite"
        let target = safetyFolder.appendingPathComponent(name)
        try db.run("VACUUM INTO ?1", [.text(target.path)])
        return target
    }

    static func dayStamp(_ date: Date, timeZone: TimeZone) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }
}
