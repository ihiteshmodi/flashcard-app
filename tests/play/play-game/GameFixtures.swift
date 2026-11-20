import Foundation
@testable import FlashcardsCore

/// A card file with numbered white cards ("s-w-1" ...) and the given black cards ("s-b-1" ...), all in the set "s".
enum GameFixtures {
    static let blacks = ["One _____.", "Two _____.", "Three _____.", "Four _____."]

    static func data(whites: Int = 60, blacks: [String] = GameFixtures.blacks) -> Data {
        let black = blacks.enumerated().map { #"{"id":"s-b-\#($0.offset + 1)","text":"\#($0.element)"}"# }.joined(separator: ",")
        let white = (0..<whites).map { #"{"id":"s-w-\#($0 + 1)","text":"White \#($0 + 1)"}"# }.joined(separator: ",")
        return Data(#"{"version":1,"sets":[{"id":"s","title":"S","black":[\#(black)],"white":[\#(white)]}]}"#.utf8)
    }

    static func library(whites: Int = 60, blacks: [String] = GameFixtures.blacks) throws -> GameCardLibrary {
        try GameCardLibrary(files: [data(whites: whites, blacks: blacks)])
    }
}

extension Game {
    /// A test can look at any hand; the app can only ever see the hand of the player holding the phone.
    func visibleHandOf(_ player: String) -> [WhiteCard] { hands[player] ?? [] }
}
