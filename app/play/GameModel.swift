import FlashcardsCore
import SwiftUI

/// Hands the table's moves to the screens and reports a refused move. It holds no rules.
@MainActor
final class GameModel: ObservableObject {
    let app: Flashcards
    @Published private(set) var table: GameTable?
    @Published var errorMessage: String?

    init(app: Flashcards) {
        self.app = app
        table = try? app.resumeGame()
    }

    var game: Game? { table?.game }
    var cardSets: [CardSet] { app.gameCards.sets }
    var people: [ProfileSummary] { (try? app.profiles.people()) ?? [] }
    var groups: [ProfileSummary] { (try? app.profiles.groups()) ?? [] }
    var lastSetup: SavedGameSetup? { try? app.lastGameSetup() }

    func groupMemberNames(_ groupID: String) -> [String] {
        ((try? app.groups.members(of: groupID)) ?? []).map(\.name)
    }

    func askedProgress(groupID: String?, personIDs: [String], sets: Set<String>) -> (asked: Int, total: Int) {
        let blacks = app.gameCards.blackCards(in: sets)
        let targets = groupID.map { [$0] } ?? personIDs
        guard !targets.isEmpty, !blacks.isEmpty else { return (0, blacks.count) }
        let askedIDs = (try? app.gameHistory.askedBlackCardIDs(forProfiles: targets)) ?? []
        let askedInSets = blacks.filter { askedIDs.contains($0.id) }.count
        return (askedInSets, blacks.count)
    }

    func start(groupID: String?, personIDs: [String], includeMe: Bool, sets: Set<String>) {
        do {
            table = try app.startGame(groupID: groupID, personIDs: personIDs, includeMe: includeMe, sets: sets)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func resetAsked(groupID: String?, personIDs: [String]) {
        do {
            try app.resetAskedGameCards(groupID: groupID, personIDs: personIDs)
            objectWillChange.send()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func ready() { move { try $0.ready() } }
    func submit(_ cardIDs: [String]) { move { try $0.submit(cardIDs) } }
    func nextRound() { move { try $0.nextRound() } }
    func resetAndContinue() { move { try $0.resetAndContinue() } }

    func end() {
        guard let table else { return }
        do {
            try table.end()
            self.table = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func move(_ change: (GameTable) throws -> Void) {
        guard let table else { return }
        do {
            try change(table)
            objectWillChange.send()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
