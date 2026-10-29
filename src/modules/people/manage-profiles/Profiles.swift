import Foundation

public enum ProfileError: Error, LocalizedError, Equatable {
    case emptyName
    case duplicateName(String)
    case noMembers
    case lastMember

    public var errorDescription: String? {
        switch self {
        case .emptyName: return "Enter a name"
        case .duplicateName(let name): return "A profile named \(name) already exists"
        case .noMembers: return "Pick at least one person"
        case .lastMember: return "A group needs at least one person"
        }
    }
}

public struct ProfileSummary: Identifiable, Equatable {
    public let profile: Profile
    public let progress: Progress
    public let answerCount: Int
    public let memberCount: Int
    public var id: String { profile.id }
}

public struct DeletionImpact: Equatable {
    public let asked: Int
    public let answers: Int
}

public final class Profiles {
    private static let selectedKey = "selected_profile"
    let db: Database
    let roles: Roles

    init(db: Database, roles: Roles) {
        self.db = db
        self.roles = roles
    }

    @discardableResult
    public func addPerson(name: String, emoji: String = "🙂") throws -> Profile {
        try create(kind: .person, name: name, emoji: emoji)
    }

    public func rename(_ id: String, to name: String) throws {
        let trimmed = try validName(name, excluding: id)
        try db.run(
            "UPDATE profile SET name = ?2, name_key = ?3 WHERE id = ?1",
            [.text(id), .text(trimmed), .text(trimmed.lowercased())])
    }

    public func delete(_ id: String) throws {
        try db.transaction {
            try db.run("DELETE FROM profile WHERE id = ?1", [.text(id)])
            if try db.setting(Self.selectedKey) == id {
                let next = try db.firstRow("SELECT id FROM profile ORDER BY created_at, rowid LIMIT 1")
                try db.setSetting(Self.selectedKey, next?.string("id"))
            }
        }
    }

    public func impactOfDeleting(_ id: String) throws -> DeletionImpact {
        DeletionImpact(
            asked: try db.count(
                "SELECT COUNT(*) AS n FROM card_state WHERE profile_id = ?1 AND status = 'asked'", [.text(id)]),
            answers: try db.count("SELECT COUNT(*) AS n FROM answer WHERE profile_id = ?1", [.text(id)]))
    }

    public func people() throws -> [ProfileSummary] { try summaries(of: .person) }

    public func groups() throws -> [ProfileSummary] { try summaries(of: .group) }

    public func profile(_ id: String) throws -> Profile? {
        try db.firstRow("SELECT * FROM profile WHERE id = ?1", [.text(id)]).map(Profile.init(row:))
    }

    public func selectedProfile() throws -> Profile? {
        if let id = try db.setting(Self.selectedKey), let chosen = try profile(id) { return chosen }
        return try db.firstRow("SELECT * FROM profile ORDER BY created_at, rowid LIMIT 1").map(Profile.init(row:))
    }

    public func select(_ id: String) throws {
        try db.setSetting(Self.selectedKey, id)
    }

    func create(kind: ProfileKind, name: String, emoji: String) throws -> Profile {
        let trimmed = try validName(name, excluding: nil)
        let symbol = emoji.trimmingCharacters(in: .whitespaces).isEmpty ? (kind == .person ? "🙂" : "👥") : emoji
        let id = roles.newID()
        try db.run(
            "INSERT INTO profile(id, kind, name, emoji, name_key, created_at) VALUES(?1, ?2, ?3, ?4, ?5, ?6)",
            [.text(id), .text(kind.rawValue), .text(trimmed), .text(symbol), .text(trimmed.lowercased()), .date(roles.now())])
        try select(id)
        return Profile(id: id, kind: kind, name: trimmed, emoji: symbol)
    }

    private func validName(_ name: String, excluding id: String?) throws -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw ProfileError.emptyName }
        let clash = try db.firstRow(
            "SELECT name FROM profile WHERE name_key = ?1 AND id != ?2",
            [.text(trimmed.lowercased()), .text(id ?? "")])
        if let clash { throw ProfileError.duplicateName(clash.string("name")) }
        return trimmed
    }

    private func summaries(of kind: ProfileKind) throws -> [ProfileSummary] {
        let rows = try db.rows(
            "SELECT * FROM profile WHERE kind = ?1 ORDER BY name_key", [.text(kind.rawValue)])
        return try rows.map { row in
            let profile = Profile(row: row)
            return ProfileSummary(
                profile: profile,
                progress: try CardStates.progress(db, profileID: profile.id),
                answerCount: try db.count(
                    """
                    SELECT COUNT(*) AS n FROM answer
                    JOIN card_state ON card_state.profile_id = answer.profile_id AND card_state.card_id = answer.card_id
                    WHERE answer.profile_id = ?1 AND card_state.status = 'asked'
                    """, [.text(profile.id)]),
                memberCount: try db.count(
                    "SELECT COUNT(*) AS n FROM group_member WHERE group_id = ?1", [.text(profile.id)]))
        }
    }
}
