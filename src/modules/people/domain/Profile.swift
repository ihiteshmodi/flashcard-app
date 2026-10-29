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
}

extension Profile {
    init(row: Row) {
        self.init(
            id: row.string("id"),
            kind: ProfileKind(rawValue: row.string("kind")) ?? .person,
            name: row.string("name"),
            emoji: row.string("emoji")
        )
    }
}
