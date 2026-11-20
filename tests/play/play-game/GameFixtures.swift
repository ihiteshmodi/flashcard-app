import Foundation
@testable import FlashcardsCore

/// A card file with numbered white cards ("s-w-1" ...) and the given black cards ("s-b-1" ...), all in the set "s".
enum GameFixtures {
    static let blacks = ["One _____.", "Two _____.", "Three _____.", "Four _____."]

    static func data(setID: String = "s", title: String = "S", whites: Int = 20, blacks: [String] = GameFixtures.blacks) -> Data {
        let black = blacks.enumerated().map { #"{"id":"\#(setID)-b-\#($0.offset + 1)","text":"\#($0.element)"}"# }.joined(separator: ",")
        let white = (0..<whites).map { #"{"id":"\#(setID)-w-\#($0 + 1)","text":"White \#($0 + 1)."}"# }.joined(separator: ",")
        return Data(#"{"version":1,"sets":[{"id":"\#(setID)","title":"\#(title)","black":[\#(black)],"white":[\#(white)]}]}"#.utf8)
    }

    static func library(whites: Int = 20, blacks: [String] = GameFixtures.blacks) throws -> GameCardLibrary {
        try GameCardLibrary(files: [data(whites: whites, blacks: blacks)])
    }

    static func players(_ names: String...) -> [GamePlayer] {
        names.map { name in
            GamePlayer(id: "p-\(name.lowercased())", name: name, emoji: "🙂", profileID: "p-\(name.lowercased())")
        }
    }
}
