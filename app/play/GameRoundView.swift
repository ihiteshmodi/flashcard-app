import FlashcardsCore
import SwiftUI

struct GameRoundView: View {
    @ObservedObject var model: GameModel
    let game: Game
    @State private var showScores = false
    @State private var confirmEnd = false

    var body: some View {
        content
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Round \(game.round)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("End") { confirmEnd = true }.accessibilityIdentifier("end-game")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Scores") { showScores = true }.accessibilityIdentifier("scores")
                }
            }
            .sheet(isPresented: $showScores) { ScoresSheet(scoreboard: game.scoreboard) }
            .confirmationDialog("End the game?", isPresented: $confirmEnd, titleVisibility: .visible) {
                Button("End Game", role: .destructive) { model.end() }
                Button("Keep Playing", role: .cancel) {}
            } message: {
                Text("The final scores are shown and this game is forgotten.")
            }
    }

    @ViewBuilder
    private var content: some View {
        switch game.screen {
        case .passPhone(let name, let isCzar):
            PassPhoneView(name: name, isCzar: isCzar, onReady: model.ready)
        case .chooseCards(let player, let black, let hand):
            ChooseCardsView(player: player, black: black, hand: hand, onPlay: model.play)
                .id("\(game.round)-\(player)")
        case .judge(let czar, let black, let plays):
            JudgeView(czar: czar, black: black, plays: plays, onPick: model.choose(playAt:))
        case .roundResult(let winner, let black, let play, let scoreboard):
            ResultView(winner: winner, black: black, play: play, scoreboard: scoreboard, onNext: model.nextRound)
        }
    }
}

private struct PassPhoneView: View {
    let name: String
    let isCzar: Bool
    let onReady: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Text("Pass the phone to")
                .font(.title3)
                .foregroundStyle(.secondary)
            Text(name)
                .font(.system(size: 44, weight: .bold))
                .minimumScaleFactor(0.5)
                .multilineTextAlignment(.center)
                .accessibilityIdentifier("pass-to")
            if isCzar {
                Text("The Card Czar picks the best play.")
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button(action: onReady) {
                Text("I'm \(name)").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .accessibilityIdentifier("ready")
        }
        .padding(24)
    }
}

private struct ChooseCardsView: View {
    let player: String
    let black: BlackCard
    let hand: [WhiteCard]
    let onPlay: ([String]) -> Void
    @State private var picker: CardPicker

    init(player: String, black: BlackCard, hand: [WhiteCard], onPlay: @escaping ([String]) -> Void) {
        self.player = player
        self.black = black
        self.hand = hand
        self.onPlay = onPlay
        _picker = State(initialValue: CardPicker(pick: black.pick))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                Text("\(player)'s turn").font(.headline)
                BlackCardView(card: black)
                Text(black.pick == 1 ? "Choose 1 card" : "Choose \(black.pick) cards, in the order they read")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                ForEach(Array(hand.enumerated()), id: \.element.id) { index, card in
                    Button { picker.toggle(card.id) } label: {
                        WhiteCardView(
                            text: card.text,
                            badge: black.pick > 1 ? picker.position(of: card.id) : nil,
                            isSelected: picker.selected.contains(card.id))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("hand-card-\(index)")
                }
            }
            .padding()
        }
        .safeAreaInset(edge: .bottom) {
            Button { onPlay(picker.selected) } label: {
                Text("Play").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!picker.isComplete)
            .padding()
            .background(.bar)
            .accessibilityIdentifier("play-cards")
        }
    }
}

private struct JudgeView: View {
    let czar: String
    let black: BlackCard
    let plays: [Game.Play]
    let onPick: (Int) -> Void
    @State private var selected: Int?

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                Text("\(czar), pick the best play").font(.headline)
                BlackCardView(card: black)
                ForEach(Array(plays.enumerated()), id: \.offset) { index, play in
                    Button { selected = index } label: {
                        VStack(spacing: 8) {
                            ForEach(play.cards) { WhiteCardView(text: $0.text, isSelected: selected == index) }
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("play-\(index)")
                }
            }
            .padding()
        }
        .safeAreaInset(edge: .bottom) {
            Button { if let selected { onPick(selected) } } label: {
                Text("Pick Winner").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(selected == nil)
            .padding()
            .background(.bar)
            .accessibilityIdentifier("pick-winner")
        }
    }
}

private struct ResultView: View {
    let winner: String
    let black: BlackCard
    let play: Game.Play
    let scoreboard: [Game.ScoreLine]
    let onNext: () -> Void

    var body: some View {
        List {
            Section {
                VStack(spacing: 14) {
                    Text("\(winner) wins the round")
                        .font(.title2.weight(.bold))
                        .accessibilityIdentifier("round-winner")
                    BlackCardView(card: black)
                    ForEach(play.cards) { WhiteCardView(text: $0.text) }
                }
                .listRowBackground(Color.clear)
            }
            Section("Scores") { ScoreList(scoreboard: scoreboard) }
        }
        .appListStyle()
        .safeAreaInset(edge: .bottom) {
            Button(action: onNext) {
                Text("Next Round").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding()
            .background(.bar)
            .accessibilityIdentifier("next-round")
        }
    }
}
