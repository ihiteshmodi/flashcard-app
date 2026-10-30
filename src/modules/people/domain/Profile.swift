import Foundation

public enum ProfileKind: String, Equatable {
    case person
    case group
}

public struct Profile: Identifiable, Equatable, Hashable {
    public let id: String
    public let kind: ProfileKind
    public let name: String
    public let emoji: String
    public let gender: Gender?
    public let closeness: Closeness

    /// "Woman · Friend" for a tagged person; empty for groups and untagged people.
    public var tagSummary: String? {
        guard kind == .person else { return nil }
        guard let gender else { return nil }
        return "\(gender.title) · \(closeness.title)"
    }
}

extension Profile {
    init(row: Row) {
        self.init(
            id: row.string("id"),
            kind: ProfileKind(rawValue: row.string("kind")) ?? .person,
            name: row.string("name"),
            emoji: row.string("emoji"),
            gender: row.optionalString("gender").flatMap(Gender.init(rawValue:)),
            closeness: Closeness(rawValue: row.string("closeness")) ?? .friend
        )
    }
}
