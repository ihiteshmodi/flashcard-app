import FlashcardsCore
import SwiftUI

struct CardsView: View {
    let app: Flashcards
    @State private var isSwitching = false
    @State private var isChoosingDecks = false

    var body: some View {
        let _ = app.database.revision
        let profile = try? app.profiles.selectedProfile()
        NavigationStack {
            Group {
                if let profile {
                    StackScreen(app: app, profile: profile)
                        .id(profile.id)
                } else {
                    ContentUnavailableView(
                        "No Profiles Yet", systemImage: "person.2",
                        description: Text("Add your first profile in the Profiles tab, then come back to start asking."))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.background.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if let profile {
                    ToolbarItem(placement: .topBarLeading) {
                        Button { isSwitching = true } label: {
                            HStack(spacing: 6) {
                                Text("\(profile.emoji) \(profile.name)").font(.subheadline.weight(.semibold))
                                Image(systemName: "chevron.down").font(.caption.weight(.bold))
                            }
                            .foregroundStyle(.primary)
                            .padding(.horizontal, 4)
                        }
                        .accessibilityLabel("\(profile.name), switch profile")
                        .accessibilityIdentifier("profile-chip")
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Decks") { isChoosingDecks = true }
                            .accessibilityIdentifier("decks-button")
                    }
                }
            }
            .sheet(isPresented: $isSwitching) { ProfileSwitcherSheet(app: app) }
            .sheet(isPresented: $isChoosingDecks) {
                if let profile { DeckChoicesSheet(app: app, profile: profile) }
            }
        }
    }
}

private struct StackScreen: View {
    let app: Flashcards
    let profile: Profile
    @State private var drag: CGSize = .zero
    @State private var pendingAnswer: Card?
    @State private var errorMessage: String?
    @State private var isAnimatingOut = false

    private var session: CardSession? { try? app.session(for: profile.id) }

    var body: some View {
        if let session {
            VStack(spacing: 14) {
                if session.hasNoCards {
                    ContentUnavailableView(
                        "No Cards", systemImage: "rectangle.on.rectangle.slash",
                        description: Text("Turn on a deck, or add your own card in Library."))
                } else if session.isAllAsked {
                    allAsked(session)
                } else {
                    stack(session)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
            .onAppear { try? session.syncWithLibrary() }
            .onChange(of: app.database.revision) { _, _ in try? session.syncWithLibrary() }
            .sheet(item: $pendingAnswer) { card in
                NoteSheet(app: app, profile: profile, card: card, title: "Save Answer")
            }
            .errorAlert($errorMessage)
        }
    }

    private func stack(_ session: CardSession) -> some View {
        let titles = deckTitles()
        return VStack(spacing: 14) {
            ZStack {
                ForEach(Array(session.stack.prefix(3).enumerated()).reversed(), id: \.element.id) { index, card in
                    CardFace(card: card, deckTitle: titles[card.deckID] ?? "")
                        .scaleEffect(1 - CGFloat(index) * 0.05, anchor: .top)
                        .offset(x: index == 0 ? drag.width : 0, y: CGFloat(index) * 16 + (index == 0 ? drag.height : 0))
                        .rotationEffect(.degrees(index == 0 ? Double(drag.width) / 22 : 0))
                        .opacity(index == 0 ? 1 : 1 - Double(index) * 0.2)
                        .overlay(alignment: .top) {
                            if index == 0 { directionHint }
                        }
                }
            }
            .frame(height: 500, alignment: .top)
            .gesture(
                DragGesture()
                    .onChanged { if !isAnimatingOut { drag = $0.translation } }
                    .onEnded { value in
                        if value.translation.width > 110 { commit(.right, session) }
                        else if value.translation.width < -110 { commit(.left, session) }
                        else { withAnimation(.spring(duration: 0.3)) { drag = .zero } }
                    }
            )
            Text("\(session.progress.asked) of \(session.progress.total) asked · \(session.progress.left) left")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("progress")
            actions(session)
            Spacer(minLength: 0)
        }
    }

    private var directionHint: some View {
        let strength = min(abs(drag.width) / 110, 1)
        return Text(drag.width >= 0 ? "Asked" : "Skip")
            .font(.headline)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(Capsule().fill(drag.width >= 0 ? Color.green : Color.orange))
            .foregroundStyle(.white)
            .padding(.top, 20)
            .opacity(strength)
    }

    private func actions(_ session: CardSession) -> some View {
        HStack(spacing: 22) {
            roundButton("arrow.uturn.backward", size: 44, tint: .accentColor, id: "undo-button", label: "Undo") {
                perform { try session.undo() }
            }
            .disabled(!session.canUndo)
            roundButton("xmark", size: 64, tint: .orange, id: "skip-button", label: "Skip") { commit(.left, session) }
            roundButton("checkmark", size: 64, tint: .green, id: "asked-button", label: "Asked") { commit(.right, session) }
            roundButton("arrow.uturn.forward", size: 44, tint: .accentColor, id: "redo-button", label: "Redo") {
                perform { try session.redo() }
            }
            .disabled(!session.canRedo)
        }
    }

    private func roundButton(_ symbol: String, size: CGFloat, tint: Color, id: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size * 0.4, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: size, height: size)
                .background(Circle().fill(Theme.raised))
                .shadow(color: .black.opacity(0.1), radius: 6, y: 2)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityIdentifier(id)
    }

    private func allAsked(_ session: CardSession) -> some View {
        VStack(spacing: 16) {
            ContentUnavailableView(
                "All Asked", systemImage: "party.popper",
                description: Text("\(profile.name) has been asked every card in the chosen decks. Saved answers are kept."))
            Button("Start Over for \(profile.name)") {
                perform { try session.startOver() }
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("start-over")
            Text("Or turn on more decks with Decks.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private enum Direction { case left, right }

    private func commit(_ direction: Direction, _ session: CardSession) {
        guard !isAnimatingOut, session.topCard != nil else { return }
        isAnimatingOut = true
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        withAnimation(.easeOut(duration: 0.18)) {
            drag = CGSize(width: direction == .right ? 700 : -700, height: drag.height)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            perform {
                if direction == .right {
                    if let asked = try session.swipeRight(), asked.kind.collectsAnswer { pendingAnswer = asked }
                } else {
                    try session.swipeLeft()
                }
            }
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) { drag = .zero }
            isAnimatingOut = false
        }
    }

    private func perform(_ action: () throws -> Void) {
        do { try action() } catch { errorMessage = error.localizedDescription }
    }

    private func deckTitles() -> [String: String] {
        let rows = (try? app.decks.rows(for: profile.id)) ?? []
        return Dictionary(uniqueKeysWithValues: rows.map { ($0.deck.id, $0.deck.title) })
    }
}
