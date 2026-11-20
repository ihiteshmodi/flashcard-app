import FlashcardsCore
import SwiftUI

struct GameView: View {
    @StateObject private var model: GameModel

    init(app: Flashcards) {
        _model = StateObject(wrappedValue: GameModel(app: app))
    }

    var body: some View {
        NavigationStack {
            Group {
                if let game = model.game {
                    GameRoundView(model: model, game: game)
                } else {
                    GameSetupView(model: model)
                }
            }
        }
        .errorAlert($model.errorMessage)
    }
}

struct GameSetupView: View {
    @ObservedObject var model: GameModel
    @State private var names: [String]
    @State private var chosen: Set<String>

    init(model: GameModel) {
        self.model = model
        let last = model.lastSetup
        _names = State(initialValue: last?.players ?? ["", "", ""])
        _chosen = State(initialValue: last?.sets ?? Set(model.cardSets.map(\.id)))
    }

    var body: some View {
        Form {
            if let scores = model.finalScores {
                Section("Final Scores") { ScoreList(scoreboard: scores) }
            }
            Section {
                ForEach(names.indices, id: \.self) { index in
                    TextField("Player \(index + 1)", text: $names[index])
                        .textInputAutocapitalization(.words)
                        .accessibilityIdentifier("player-name-\(index)")
                }
                .onDelete { names.remove(atOffsets: $0) }
                Button("Add Player") { names.append("") }
                    .disabled(names.count >= Game.maximumPlayers)
                    .accessibilityIdentifier("add-player")
            } header: {
                Text("Players")
            } footer: {
                Text("\(Game.minimumPlayers) to \(Game.maximumPlayers) players. The first one is the first Card Czar.")
            }
            Section {
                ForEach(model.cardSets) { set in
                    Toggle(isOn: binding(for: set.id)) {
                        VStack(alignment: .leading) {
                            Text(set.title)
                            Text("\(set.blackCards.count) black, \(set.whiteCards.count) white")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityIdentifier("set-\(set.id)")
                }
            } header: {
                Text("Card Sets")
            }
            Section {
                Button("Start Game") {
                    model.start(players: names.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }, sets: chosen)
                }
                .accessibilityIdentifier("start-game")
            }
        }
        .appListStyle()
        .navigationTitle("Party Game")
    }

    private func binding(for setID: String) -> Binding<Bool> {
        Binding(
            get: { chosen.contains(setID) },
            set: { isOn in
                if isOn { chosen.insert(setID) } else { chosen.remove(setID) }
            })
    }
}
