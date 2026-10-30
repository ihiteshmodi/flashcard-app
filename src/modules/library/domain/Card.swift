import Foundation

public enum CardKind: String, Codable, CaseIterable {
    case question
    case topic
    case upgrade
    case dare
    case multipleChoice
    case thisOrThat

    /// Dares are only marked done; every other kind can carry a note.
    public var collectsAnswer: Bool { self != .dare }
    public var hasOptions: Bool { self == .multipleChoice || self == .thisOrThat }
}

public struct Deck: Identifiable, Equatable, Hashable {
    public let id: String
    public let title: String
    public let isBuiltIn: Bool
}

public struct Card: Identifiable, Equatable, Hashable {
    public let id: String
    public let deckID: String
    public let category: String?
    public let kind: CardKind
    public let prompt: String
    public let detail: String?
    public let options: [String]
    public let isBuiltIn: Bool
    public let audience: Audience
    public let spice: Spice
    public let perspective: Perspective
}

extension Deck {
    init(row: Row) {
        self.init(id: row.string("id"), title: row.string("title"), isBuiltIn: row.bool("is_builtin"))
    }
}

extension Card {
    init(row: Row) {
        let optionData = Data(row.string("options").utf8)
        self.init(
            id: row.string("id"),
            deckID: row.string("deck_id"),
            category: row.optionalString("category"),
            kind: CardKind(rawValue: row.string("kind")) ?? .question,
            prompt: row.string("prompt"),
            detail: row.optionalString("detail"),
            options: (try? JSONDecoder().decode([String].self, from: optionData)) ?? [],
            isBuiltIn: row.bool("is_builtin"),
            audience: Audience(rawValue: row.string("audience")) ?? .everyone,
            spice: Spice(rawValue: row.string("spice")) ?? .safe,
            perspective: Perspective(rawValue: row.string("perspective")) ?? .anyone
        )
    }

    static func encodeOptions(_ options: [String]) -> String {
        let data = (try? JSONEncoder().encode(options)) ?? Data("[]".utf8)
        return String(decoding: data, as: UTF8.self)
    }
}
