import FlashcardsCore
import SwiftUI

struct GameRoundView: View {
    @ObservedObject var model: GameModel
    let game: Game
    @State private var confirmEnd = false

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle(game.screen == .allAsked ? "Party Game" : "Round \(game.round)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("End") { confirmEnd = true }.accessibilityIdentifier("end-game")
                }
            }
            .confirmationDialog("End the game?", isPresented: $confirmEnd, titleVisibility: .visible) {
                Button("End Game", role: .destructive) { model.end() }
                Button("Keep Playing", role: .cancel) {}
            } message: {
                Text("Finished rounds stay in History.")
            }
    }

    @ViewBuilder
    private var content: some View {
        switch game.screen {
        case .passPhone(let player):
            PassPhoneView(player: player, onReady: model.ready)
        case .chooseCards(let player, let black, let options):
            ChooseCardsView(player: player, black: black, options: options, onSubmit: model.submit)
                .id("\(game.round)-\(player.id)")
        case .reveal(let black, let answers):
            RevealRoundView(black: black, answers: answers, onNext: model.nextRound)
        case .allAsked:
            AllAskedGameView(onReset: model.resetAndContinue, onEnd: model.end)
        }
    }
}

private struct PassPhoneView: View {
    let player: GamePlayer
    let onReady: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            AvatarView(emoji: player.emoji, size: 72)
            Text("Pass the phone to")
                .font(.title3)
                .foregroundStyle(.secondary)
            Text(player.name)
                .font(.system(size: 44, weight: .bold))
                .minimumScaleFactor(0.5)
                .multilineTextAlignment(.center)
                .accessibilityIdentifier("pass-to")
            Text("Everyone's answers stay hidden until the last player finishes.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
            Button(action: onReady) {
                Text("I'm \(player.name)").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .accessibilityIdentifier("ready")
        }
        .padding(24)
    }
}

private struct ChooseCardsView: View {
    let player: GamePlayer
    let black: BlackCard
    let options: [WhiteCard]
    let onSubmit: ([String]) -> Void
    @State private var picker: CardPicker

    init(player: GamePlayer, black: BlackCard, options: [WhiteCard], onSubmit: @escaping ([String]) -> Void) {
        self.player = player
        self.black = black
        self.options = options
        self.onSubmit = onSubmit
        _picker = State(initialValue: CardPicker(pick: black.pick))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                Text("\(player.emoji) \(player.name)'s turn").font(.headline)
                BlackCardView(card: black)
                Text(black.pick == 1
                     ? "Choose 1 answer · everyone sees the same options"
                     : "Choose \(black.pick) answers, in the order they read")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                ForEach(Array(options.enumerated()), id: \.element.id) { index, card in
                    Button { picker.toggle(card.id) } label: {
                        WhiteCardView(
                            text: card.text,
                            badge: black.pick > 1 ? picker.position(of: card.id) : nil,
                            isSelected: picker.selected.contains(card.id))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("option-card-\(index)")
                }
            }
            .padding()
        }
        .safeAreaInset(edge: .bottom) {
            Button { onSubmit(picker.selected) } label: {
                Text("Lock In Answer").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!picker.isComplete)
            .padding()
            .background(.bar)
            .accessibilityIdentifier("submit-cards")
        }
    }
}

private struct RevealRoundView: View {
    let black: BlackCard
    let answers: [Game.PlayerAnswer]
    let onNext: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Everyone's Answers")
                    .font(.title2.weight(.bold))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .accessibilityIdentifier("reveal-header")
                BlackCardView(card: black)
                ForEach(answers, id: \.player.id) { entry in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            AvatarView(emoji: entry.player.emoji, size: 28)
                            Text(entry.player.name)
                                .font(.headline)
                        }
                        ForEach(entry.cards) { card in
                            WhiteCardView(text: card.text)
                        }
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(entry.player.name): \(entry.cards.map(\.text).joined(separator: ", "))")
                    .accessibilityIdentifier("reveal-\(entry.player.name)")
                }
            }
            .padding()
        }
        .safeAreaInset(edge: .bottom) {
            Button(action: onNext) {
                Text("Next Question").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding()
            .background(.bar)
            .accessibilityIdentifier("next-round")
        }
    }
}

private struct AllAskedGameView: View {
    let onReset: () -> Void
    let onEnd: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            ContentUnavailableView(
                "All Questions Played",
                systemImage: "party.popper",
                description: Text("You have played every black card in the chosen sets for these players. Past answers stay in History."))
            Button("Start Over") { onReset() }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .accessibilityIdentifier("game-start-over")
            Button("Back to Setup") { onEnd() }
                .accessibilityIdentifier("back-to-setup")
        }
        .padding(24)
    }
}
