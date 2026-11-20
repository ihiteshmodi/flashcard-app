import FlashcardsCore
import SwiftUI

/// Hands the table's moves to the screens and reports a refused move. It holds no rules.
@MainActor
final class GameModel: ObservableObject {
    let app: Flashcards
    @Published private(set) var table: GameTable?
    @Published var finalScores: [Game.ScoreLine]?
    @Published var errorMessage: String?

    init(app: Flashcards) {
        self.app = app
        table = try? app.resumeGame()
    }

    var game: Game? { table?.game }
    var cardSets: [CardSet] { app.gameCards.sets }
    var lastSetup: (players: [String], sets: Set<String>)? { try? app.lastGameSetup() }

    func start(players: [String], sets: Set<String>) {
        do {
            table = try app.startGame(players: players, sets: sets)
            finalScores = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func ready() { move { try $0.ready() } }
    func play(_ cardIDs: [String]) { move { try $0.play(cardIDs) } }
    func choose(playAt index: Int) { move { try $0.choose(playAt: index) } }
    func nextRound() { move { try $0.nextRound() } }

    func end() {
        guard let table else { return }
        do {
            finalScores = try table.end()
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
