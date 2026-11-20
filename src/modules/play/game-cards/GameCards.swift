import Foundation

public struct BlackCard: Identifiable, Equatable, Codable {
    public let id: String
    public let setID: String
    public let text: String
    public let pick: Int
}

public struct WhiteCard: Identifiable, Equatable, Codable {
    public let id: String
    public let setID: String
    public let text: String
}

public struct CardSet: Identifiable, Equatable {
    public let id: String
    public let title: String
    public let blackCards: [BlackCard]
    public let whiteCards: [WhiteCard]
}

private struct GameCardFile: Decodable {
    struct Black: Decodable {
        let id: String
        let text: String
        let pick: Int?
    }

    struct White: Decodable {
        let id: String
        let text: String
    }

    struct Set: Decodable {
        let id: String
        let title: String
        let black: [Black]
        let white: [White]
    }

    let version: Int
    let sets: [Set]
}

/// The black and white cards of the party game, grouped in sets that can be switched on per game.
public struct GameCardLibrary {
    public let sets: [CardSet]

    /// Each file adds its sets after the ones before it, so a private file can extend the public one.
    public init(files: [Data]) throws {
        var sets: [CardSet] = []
        var ids = Swift.Set<String>()
        for data in files {
            let file: GameCardFile
            do {
                file = try JSONDecoder().decode(GameCardFile.self, from: data)
            } catch {
                throw SeedError.unreadable(error.localizedDescription)
            }
            for set in file.sets {
                let black = set.black.map {
                    BlackCard(id: $0.id, setID: set.id, text: $0.text, pick: $0.pick ?? Self.blankCount(in: $0.text))
                }
                let white = set.white.map { WhiteCard(id: $0.id, setID: set.id, text: $0.text) }
                for id in black.map(\.id) + white.map(\.id) where !ids.insert(id).inserted {
                    throw SeedError.unreadable("the card id \(id) is used twice")
                }
                sets.append(CardSet(id: set.id, title: set.title, blackCards: black, whiteCards: white))
            }
        }
        self.sets = sets
    }

    public func blackCards(in setIDs: Swift.Set<String>) -> [BlackCard] {
        distinct(sets.filter { setIDs.contains($0.id) }.flatMap(\.blackCards), by: \.text)
    }

    public func whiteCards(in setIDs: Swift.Set<String>) -> [WhiteCard] {
        distinct(sets.filter { setIDs.contains($0.id) }.flatMap(\.whiteCards), by: \.text)
    }

    /// A card printed in several editions is dealt once; the first enabled set that has it keeps it.
    private func distinct<Card>(_ cards: [Card], by text: KeyPath<Card, String>) -> [Card] {
        var seen = Swift.Set<String>()
        return cards.filter { seen.insert(Self.normalized($0[keyPath: text])).inserted }
    }

    private static func normalized(_ text: String) -> String {
        text.lowercased().split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    /// A blank is a run of underscores; a card with none (a question) still takes one answer.
    private static func blankCount(in text: String) -> Int {
        max(1, text.split { $0 != "_" }.count)
    }
}
