import Foundation

/// What the player holding the phone sees. The screens only draw this; they decide nothing.
public enum GameScreen: Equatable {
    case passPhone(to: GamePlayer)
    case chooseCards(player: GamePlayer, black: BlackCard, options: [WhiteCard])
    case reveal(black: BlackCard, answers: [Game.PlayerAnswer])
    case allAsked
}

extension Game {
    public var screen: GameScreen {
        switch phase {
        case .passToPlayer(let player): return .passPhone(to: player)
        case .choosing(let player): return .chooseCards(player: player, black: blackCard, options: visibleOptions)
        case .reveal(let answers): return .reveal(black: blackCard, answers: answers)
        case .allAsked: return .allAsked
        }
    }
}

/// The white cards touched so far for one black card, in the order they will be read.
public struct CardPicker: Equatable {
    public let pick: Int
    public private(set) var selected: [String] = []

    public init(pick: Int) { self.pick = pick }

    public var isComplete: Bool { selected.count == pick }

    /// With a pick of one the last card touched wins; with more, a full pick has to give a card up first.
    public mutating func toggle(_ id: String) {
        if let index = selected.firstIndex(of: id) {
            selected.remove(at: index)
        } else if pick == 1 {
            selected = [id]
        } else if selected.count < pick {
            selected.append(id)
        }
    }

    public func position(of id: String) -> Int? {
        selected.firstIndex(of: id).map { $0 + 1 }
    }
}
