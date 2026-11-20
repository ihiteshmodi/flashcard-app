import Foundation

/// What the player holding the phone sees. The screens only draw this; they decide nothing.
public enum GameScreen: Equatable {
    case passPhone(to: String, isCzar: Bool)
    case chooseCards(player: String, black: BlackCard, hand: [WhiteCard])
    case judge(czar: String, black: BlackCard, plays: [Game.Play])
    case roundResult(winner: String, black: BlackCard, play: Game.Play, scoreboard: [Game.ScoreLine])
}

extension Game {
    public var screen: GameScreen {
        switch phase {
        case .passToPlayer(let player): return .passPhone(to: player, isCzar: false)
        case .choosing(let player): return .chooseCards(player: player, black: blackCard, hand: visibleHand)
        case .passToCzar: return .passPhone(to: czar, isCzar: true)
        case .judging: return .judge(czar: czar, black: blackCard, plays: plays)
        case .roundResult(let winner, let play): return .roundResult(winner: winner, black: blackCard, play: play, scoreboard: scoreboard)
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
