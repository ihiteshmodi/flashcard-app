import Foundation

public enum GameError: Error, LocalizedError, Equatable {
    case needMorePlayers
    case tooManyPlayers
    case blankName
    case duplicateName
    case noSetChosen
    case notEnoughWhiteCards(players: Int)
    case noBlackCards
    case chooseCards(Int)
    case cardNotInHand
    case repeatedCard
    case outOfTurn
    case noSuchPlay

    public var errorDescription: String? {
        switch self {
        case .needMorePlayers: return "Add at least 3 players"
        case .tooManyPlayers: return "A game takes at most 10 players"
        case .blankName: return "Every player needs a name"
        case .duplicateName: return "Each player needs a different name"
        case .noSetChosen: return "Switch on at least one card set"
        case .notEnoughWhiteCards(let players): return "These sets do not have enough white cards for \(players) players"
        case .noBlackCards: return "These sets have no black cards"
        case .chooseCards(let count): return count == 1 ? "Choose 1 card" : "Choose \(count) cards"
        case .cardNotInHand: return "That card is not in your hand"
        case .repeatedCard: return "Choose different cards"
        case .outOfTurn: return "That is not possible right now"
        case .noSuchPlay: return "That play does not exist"
        }
    }
}

/// One game of the party game on a shared phone. Every change goes through the round's transitions
/// (see docs/design/play-game/state-machines.md), and a refused change leaves the game as it was.
/// Shuffling is passed in, so the rules hold no randomness.
public struct Game: Equatable, Codable {
    public static let minimumPlayers = 3
    public static let maximumPlayers = 10

    public enum Phase: Equatable, Codable {
        case passToPlayer(String)
        case choosing(String)
        case passToCzar
        case judging
        case roundResult(winner: String, play: Play)
    }

    /// What one player put down. It deliberately has no player: the Czar judges anonymously.
    public struct Play: Equatable, Codable {
        public let cards: [WhiteCard]
    }

    public struct ScoreLine: Equatable {
        public let name: String
        public let points: Int
        public let isCzar: Bool
    }

    public let players: [String]
    public let handSize: Int
    public private(set) var phase: Phase
    public private(set) var round = 1
    public private(set) var blackCard: BlackCard
    var hands: [String: [WhiteCard]] = [:]
    private var points: [String: Int] = [:]
    private var whitePile: [WhiteCard]
    private var whiteDiscards: [WhiteCard] = []
    private var blackPile: [BlackCard]
    private var blackDiscards: [BlackCard] = []
    private var turnOrder: [String] = []
    private var judgingOrder: [String] = []
    private var submissions: [String: [WhiteCard]] = [:]

    public var czar: String { players[(round - 1) % players.count] }

    public var scoreboard: [ScoreLine] {
        players.map { ScoreLine(name: $0, points: points[$0] ?? 0, isCzar: $0 == czar) }
    }

    /// Only the hand of the player who has said the phone is theirs; nobody else's is ever readable.
    public var visibleHand: [WhiteCard] {
        guard case .choosing(let player) = phase else { return [] }
        return hands[player] ?? []
    }

    /// The plays in the order the Czar judges them, once the Czar has the phone.
    public var plays: [Play] {
        guard phase == .judging else { return [] }
        return judgingOrder.compactMap { submissions[$0].map(Play.init) }
    }

    public static func start(players: [String], library: GameCardLibrary, sets: Set<String>, handSize: Int = 10,
                             shuffle: ([String]) -> [String]) throws -> Game {
        guard players.count >= minimumPlayers else { throw GameError.needMorePlayers }
        guard players.count <= maximumPlayers else { throw GameError.tooManyPlayers }
        let names = players.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        guard !names.contains(where: \.isEmpty) else { throw GameError.blankName }
        guard Set(names.map { $0.lowercased() }).count == names.count else { throw GameError.duplicateName }
        guard !sets.isEmpty else { throw GameError.noSetChosen }
        let whites = library.whiteCards(in: sets)
        guard whites.count >= names.count * handSize else { throw GameError.notEnoughWhiteCards(players: names.count) }
        var blacks = shuffled(library.blackCards(in: sets), with: shuffle)
        guard !blacks.isEmpty else { throw GameError.noBlackCards }

        var game = Game(players: names, handSize: handSize, blackCard: blacks.removeFirst(), blackPile: blacks,
                        whitePile: shuffled(whites, with: shuffle))
        for player in names { game.hands[player] = game.drawWhite(handSize, shuffle) }
        game.openRound(shuffle)
        return game
    }

    private init(players: [String], handSize: Int, blackCard: BlackCard, blackPile: [BlackCard], whitePile: [WhiteCard]) {
        self.players = players
        self.handSize = handSize
        self.blackCard = blackCard
        self.blackPile = blackPile
        self.whitePile = whitePile
        phase = .passToCzar
    }

    /// The player the phone was handed to says it is them: their hand shows, or the Czar starts judging.
    public mutating func ready() throws {
        switch phase {
        case .passToPlayer(let player): phase = .choosing(player)
        case .passToCzar: phase = .judging
        default: throw GameError.outOfTurn
        }
    }

    public mutating func play(_ cardIDs: [String]) throws {
        guard case .choosing(let player) = phase else { throw GameError.outOfTurn }
        guard cardIDs.count == blackCard.pick else { throw GameError.chooseCards(blackCard.pick) }
        let hand = hands[player] ?? []
        let chosen = cardIDs.compactMap { id in hand.first { $0.id == id } }
        guard chosen.count == cardIDs.count else { throw GameError.cardNotInHand }
        guard Set(cardIDs).count == cardIDs.count else { throw GameError.repeatedCard }

        hands[player] = hand.filter { !cardIDs.contains($0.id) }
        submissions[player] = chosen
        let next = (turnOrder.firstIndex(of: player) ?? 0) + 1
        phase = next < turnOrder.count ? .passToPlayer(turnOrder[next]) : .passToCzar
    }

    public mutating func choose(playAt index: Int) throws {
        guard phase == .judging else { throw GameError.outOfTurn }
        guard judgingOrder.indices.contains(index), let cards = submissions[judgingOrder[index]] else { throw GameError.noSuchPlay }
        let winner = judgingOrder[index]
        points[winner, default: 0] += 1
        phase = .roundResult(winner: winner, play: Play(cards: cards))
    }

    public mutating func nextRound(shuffle: ([String]) -> [String]) throws {
        guard case .roundResult = phase else { throw GameError.outOfTurn }
        whiteDiscards += turnOrder.flatMap { submissions[$0] ?? [] }
        blackDiscards.append(blackCard)
        round += 1
        for player in players { hands[player, default: []] += drawWhite(handSize - (hands[player]?.count ?? 0), shuffle) }
        if blackPile.isEmpty {
            blackPile = Self.shuffled(blackDiscards, with: shuffle)
            blackDiscards = []
        }
        blackCard = blackPile.removeFirst()
        openRound(shuffle)
    }

    /// The players after the Czar play in turn, and the Czar later sees their plays in a shuffled order.
    private mutating func openRound(_ shuffle: ([String]) -> [String]) {
        let start = (round - 1) % players.count
        turnOrder = (1..<players.count).map { players[(start + $0) % players.count] }
        judgingOrder = shuffle(turnOrder)
        submissions = [:]
        phase = .passToPlayer(turnOrder[0])
    }

    /// A pile that runs out is made again from the cards already used.
    private mutating func drawWhite(_ count: Int, _ shuffle: ([String]) -> [String]) -> [WhiteCard] {
        var drawn: [WhiteCard] = []
        for _ in 0..<max(count, 0) {
            if whitePile.isEmpty {
                whitePile = Self.shuffled(whiteDiscards, with: shuffle)
                whiteDiscards = []
            }
            drawn.append(whitePile.removeFirst())
        }
        return drawn
    }

    private static func shuffled<Card: Identifiable>(_ cards: [Card], with shuffle: ([String]) -> [String]) -> [Card]
    where Card.ID == String {
        let byID = Dictionary(uniqueKeysWithValues: cards.map { ($0.id, $0) })
        return shuffle(cards.map(\.id)).compactMap { byID[$0] }
    }
}
