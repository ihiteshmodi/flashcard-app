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
    @State private var selectedGroupID: String?
    @State private var selectedPersonIDs: [String]
    @State private var includeMe: Bool
    @State private var chosenSets: Set<String>
    @State private var isAddingPerson = false
    @State private var knownPersonIDs: Set<String> = []

    init(model: GameModel) {
        self.model = model
        let last = model.lastSetup
        let allSetIDs = Set(model.cardSets.map(\.id))
        let savedSets = last?.sets.intersection(allSetIDs) ?? []
        _selectedGroupID = State(initialValue: last?.groupID)
        _selectedPersonIDs = State(initialValue: last?.personIDs ?? [])
        _includeMe = State(initialValue: last?.includeMe ?? false)
        _chosenSets = State(initialValue: savedSets.isEmpty ? allSetIDs : savedSets)
    }

    var body: some View {
        let _ = model.app.database.revision
        let people = model.people
        let groups = model.groups
        let validGroupID = groups.contains(where: { $0.id == selectedGroupID }) ? selectedGroupID : nil
        let validPersonIDs = selectedPersonIDs.filter { id in people.contains(where: { $0.id == id }) }
        let progress = model.askedProgress(groupID: validGroupID, personIDs: validPersonIDs, sets: chosenSets)

        Form {
            if !groups.isEmpty {
                Section {
                    ForEach(groups) { summary in
                        let isChosen = validGroupID == summary.id
                        Button {
                            selectedGroupID = isChosen ? nil : summary.id
                        } label: {
                            HStack(spacing: 12) {
                                AvatarView(emoji: summary.profile.emoji)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(summary.profile.name).foregroundStyle(.primary)
                                    let names = model.groupMemberNames(summary.id)
                                    Text(names.joined(separator: ", "))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: isChosen ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(isChosen ? Color.accentColor : .secondary)
                            }
                        }
                        .listRowBackground(Theme.surface)
                        .accessibilityIdentifier("game-group-\(summary.profile.name)")
                    }
                } header: {
                    Text("Play as a Group")
                } footer: {
                    Text("Picking a group plays with its members and saves the round in that group's History.")
                }
            }

            Section {
                Toggle(isOn: $includeMe) {
                    HStack(spacing: 12) {
                        AvatarView(emoji: GamePlayer.me.emoji)
                        Text("Include Me")
                    }
                }
                .listRowBackground(Theme.surface)
                .accessibilityIdentifier("include-me")

                if validGroupID == nil {
                    ForEach(people) { summary in
                        let isChosen = validPersonIDs.contains(summary.id)
                        Button { togglePerson(summary.id) } label: {
                            HStack(spacing: 12) {
                                AvatarView(emoji: summary.profile.emoji)
                                Text(summary.profile.name).foregroundStyle(.primary)
                                Spacer()
                                Image(systemName: isChosen ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(isChosen ? Color.accentColor : .secondary)
                            }
                        }
                        .listRowBackground(Theme.surface)
                        .accessibilityIdentifier("game-person-\(summary.profile.name)")
                    }
                    Button {
                        knownPersonIDs = Set(people.map(\.id))
                        isAddingPerson = true
                    } label: {
                        Label("New Person…", systemImage: "person.badge.plus")
                    }
                    .listRowBackground(Theme.surface)
                    .accessibilityIdentifier("game-new-person")
                }
            } header: {
                Text(validGroupID == nil ? "Players" : "Host")
            } footer: {
                Text(validGroupID == nil
                     ? "Tap people from your Profiles. Each finished round is saved to their History."
                     : "Turn on Include Me if you are also answering alongside the group.")
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
                    .listRowBackground(Theme.surface)
                    .accessibilityIdentifier("set-\(set.id)")
                }
                if progress.asked > 0 {
                    Button("Reset Asked Questions (\(progress.asked) of \(progress.total) played)") {
                        model.resetAsked(groupID: validGroupID, personIDs: validPersonIDs)
                    }
                    .listRowBackground(Theme.surface)
                    .accessibilityIdentifier("reset-asked-game-cards")
                }
            } header: {
                Text("Card Sets")
            } footer: {
                if progress.total > 0, validGroupID != nil || !validPersonIDs.isEmpty {
                    Text("\(progress.asked) of \(progress.total) questions played for these players. Resetting keeps History.")
                }
            }
        }
        .appListStyle()
        .navigationTitle("Party Game")
        .safeAreaInset(edge: .bottom) {
            Button {
                model.start(
                    groupID: validGroupID,
                    personIDs: validPersonIDs,
                    includeMe: includeMe,
                    sets: chosenSets)
            } label: {
                Text("Start Game").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding()
            .background(.bar)
            .accessibilityIdentifier("start-game")
        }
        .sheet(isPresented: $isAddingPerson, onDismiss: selectNewlyAddedPerson) {
            ProfileFormSheet(app: model.app, mode: .newPerson)
        }
    }

    private func togglePerson(_ id: String) {
        if let index = selectedPersonIDs.firstIndex(of: id) {
            selectedPersonIDs.remove(at: index)
        } else {
            selectedPersonIDs.append(id)
        }
    }

    private func selectNewlyAddedPerson() {
        let added = model.people.map(\.id).filter { !knownPersonIDs.contains($0) }
        for id in added where !selectedPersonIDs.contains(id) {
            selectedPersonIDs.append(id)
        }
    }

    private func binding(for setID: String) -> Binding<Bool> {
        Binding(
            get: { chosenSets.contains(setID) },
            set: { isOn in
                if isOn { chosenSets.insert(setID) } else { chosenSets.remove(setID) }
            })
    }
}
