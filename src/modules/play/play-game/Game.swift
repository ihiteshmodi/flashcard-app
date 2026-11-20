import Foundation

public struct GamePlayer: Identifiable, Equatable, Codable {
    public let id: String
    public let name: String
    public let emoji: String
    public let profileID: String?

    public init(id: String, name: String, emoji: String, profileID: String?) {
        self.id = id
        self.name = name
        self.emoji = emoji
        self.profileID = profileID
    }

    public init(profile: Profile) {
        self.init(id: profile.id, name: profile.name, emoji: profile.emoji, profileID: profile.id)
    }

    public static let me = GamePlayer(id: "me", name: "Me", emoji: "🙋", profileID: nil)
}

public enum GameError: Error, LocalizedError, Equatable {
    case needMorePlayers
    case tooManyPlayers
    case blankName
    case duplicateName
    case noSetChosen
    case notEnoughWhiteCards
    case noBlackCards
    case chooseCards(Int)
    case cardNotInOptions
    case repeatedCard
    case outOfTurn

    public var errorDescription: String? {
        switch self {
        case .needMorePlayers: return "Pick at least one player"
        case .tooManyPlayers: return "A game takes at most 10 players"
        case .blankName: return "Every player needs a name"
        case .duplicateName: return "Each player needs a different name"
        case .noSetChosen: return "Switch on at least one card set"
        case .notEnoughWhiteCards: return "These sets do not have enough white cards"
        case .noBlackCards: return "These sets have no black cards"
        case .chooseCards(let count): return count == 1 ? "Choose 1 card" : "Choose \(count) cards"
        case .cardNotInOptions: return "That card is not in the options"
        case .repeatedCard: return "Choose different cards"
        case .outOfTurn: return "That is not possible right now"
        }
    }
}

/// One pass-around game on a shared phone. Every player answers the same black card from the same round options;
/// choices stay hidden until the last player submits, and white cards remain reusable across players and rounds.
public struct Game: Equatable, Codable {
    public static let minimumPlayers = 1
    public static let maximumPlayers = 10
    public static let defaultOptionCount = 12

    public struct PlayerAnswer: Equatable, Codable {
        public let player: GamePlayer
        public let cards: [WhiteCard]

        public init(player: GamePlayer, cards: [WhiteCard]) {
            self.player = player
            self.cards = cards
        }
    }

    public enum Phase: Equatable, Codable {
        case passToPlayer(GamePlayer)
        case choosing(GamePlayer)
        case reveal([PlayerAnswer])
        case allAsked
    }

    public let players: [GamePlayer]
    public let sets: Set<String>
    public let targetGroupID: String?
    public let optionCount: Int
    public private(set) var phase: Phase
    public private(set) var round: Int
    public private(set) var blackCard: BlackCard
    private var blackPile: [BlackCard]
    private let allWhiteCards: [WhiteCard]
    private var roundOptions: [WhiteCard] = []
    private var submissions: [String: [WhiteCard]] = [:]

    /// Shown only after the active player confirms the phone is in their hands.
    public var visibleOptions: [WhiteCard] {
        guard case .choosing = phase else { return [] }
        return roundOptions
    }

    /// Shown only after every player has answered for the round.
    public var revealedAnswers: [PlayerAnswer] {
        guard case .reveal(let answers) = phase else { return [] }
        return answers
    }

    public static func start(
        players: [GamePlayer],
        targetGroupID: String? = nil,
        library: GameCardLibrary,
        sets: Set<String>,
        excludedBlackIDs: Set<String> = [],
        optionCount: Int = defaultOptionCount,
        shuffle: ([String]) -> [String]
    ) throws -> Game {
        guard players.count >= minimumPlayers else { throw GameError.needMorePlayers }
        guard players.count <= maximumPlayers else { throw GameError.tooManyPlayers }
        let cleaned = players.map {
            GamePlayer(
                id: $0.id,
                name: $0.name.trimmingCharacters(in: .whitespacesAndNewlines),
                emoji: $0.emoji,
                profileID: $0.profileID)
        }
        guard !cleaned.contains(where: { $0.name.isEmpty }) else { throw GameError.blankName }
        guard Set(cleaned.map { $0.name.lowercased() }).count == cleaned.count,
              Set(cleaned.map(\.id)).count == cleaned.count else {
            throw GameError.duplicateName
        }
        guard !sets.isEmpty else { throw GameError.noSetChosen }
        let allBlacks = library.blackCards(in: sets)
        guard !allBlacks.isEmpty else { throw GameError.noBlackCards }
        let whites = library.whiteCards(in: sets)
        let neededWhites = allBlacks.map(\.pick).max() ?? 1
        guard whites.count >= neededWhites else { throw GameError.notEnoughWhiteCards }

        var fresh = shuffled(allBlacks.filter { !excludedBlackIDs.contains($0.id) }, with: shuffle)
        guard !fresh.isEmpty else {
            return Game(
                players: cleaned, sets: sets, targetGroupID: targetGroupID, optionCount: max(1, optionCount),
                phase: .allAsked, round: 0, blackCard: allBlacks[0], blackPile: [], allWhiteCards: whites)
        }
        let first = fresh.removeFirst()
        var game = Game(
            players: cleaned, sets: sets, targetGroupID: targetGroupID, optionCount: max(1, optionCount),
            phase: .passToPlayer(cleaned[0]), round: 1, blackCard: first, blackPile: fresh, allWhiteCards: whites)
        game.dealRoundOptions(for: first, shuffle: shuffle)
        return game
    }

    private init(
        players: [GamePlayer],
        sets: Set<String>,
        targetGroupID: String?,
        optionCount: Int,
        phase: Phase,
        round: Int,
        blackCard: BlackCard,
        blackPile: [BlackCard],
        allWhiteCards: [WhiteCard]
    ) {
        self.players = players
        self.sets = sets
        self.targetGroupID = targetGroupID
        self.optionCount = optionCount
        self.phase = phase
        self.round = round
        self.blackCard = blackCard
        self.blackPile = blackPile
        self.allWhiteCards = allWhiteCards
    }

    public mutating func ready() throws {
        guard case .passToPlayer(let player) = phase else { throw GameError.outOfTurn }
        phase = .choosing(player)
    }

    public mutating func submit(_ cardIDs: [String]) throws {
        guard case .choosing(let player) = phase else { throw GameError.outOfTurn }
        guard cardIDs.count == blackCard.pick else { throw GameError.chooseCards(blackCard.pick) }
        let chosen = cardIDs.compactMap { id in roundOptions.first { $0.id == id } }
        guard chosen.count == cardIDs.count else { throw GameError.cardNotInOptions }
        guard Set(cardIDs).count == cardIDs.count else { throw GameError.repeatedCard }

        submissions[player.id] = chosen
        let nextIndex = (players.firstIndex(of: player) ?? 0) + 1
        if nextIndex < players.count {
            phase = .passToPlayer(players[nextIndex])
        } else {
            let answers = players.compactMap { entry in
                submissions[entry.id].map { PlayerAnswer(player: entry, cards: $0) }
            }
            phase = .reveal(answers)
        }
    }

    public mutating func nextRound(shuffle: ([String]) -> [String]) throws {
        guard case .reveal = phase else { throw GameError.outOfTurn }
        guard !blackPile.isEmpty else {
            phase = .allAsked
            return
        }
        blackCard = blackPile.removeFirst()
        round += 1
        submissions = [:]
        dealRoundOptions(for: blackCard, shuffle: shuffle)
        phase = .passToPlayer(players[0])
    }

    public mutating func resetAndContinue(library: GameCardLibrary, shuffle: ([String]) -> [String]) throws {
        guard phase == .allAsked else { throw GameError.outOfTurn }
        var fresh = Self.shuffled(library.blackCards(in: sets), with: shuffle)
        guard !fresh.isEmpty else { throw GameError.noBlackCards }
        blackCard = fresh.removeFirst()
        blackPile = fresh
        round += 1
        submissions = [:]
        dealRoundOptions(for: blackCard, shuffle: shuffle)
        phase = .passToPlayer(players[0])
    }

    /// Prefers white cards from the black card's own edition so regional jokes match, topping up from other enabled sets.
    private mutating func dealRoundOptions(for black: BlackCard, shuffle: ([String]) -> [String]) {
        let sameEdition = Self.shuffled(allWhiteCards.filter { $0.setID == black.setID }, with: shuffle)
        if sameEdition.count >= optionCount {
            roundOptions = Array(sameEdition.prefix(optionCount))
            return
        }
        let rest = Self.shuffled(allWhiteCards.filter { $0.setID != black.setID }, with: shuffle)
        roundOptions = Array((sameEdition + rest).prefix(optionCount))
    }

    private static func shuffled<Card: Identifiable>(_ cards: [Card], with shuffle: ([String]) -> [String]) -> [Card]
    where Card.ID == String {
        let byID = Dictionary(uniqueKeysWithValues: cards.map { ($0.id, $0) })
        return shuffle(cards.map(\.id)).compactMap { byID[$0] }
    }
}
