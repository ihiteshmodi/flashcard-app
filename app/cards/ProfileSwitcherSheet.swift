import FlashcardsCore
import SwiftUI

struct ProfileSwitcherSheet: View {
    let app: Flashcards
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let _ = app.database.revision
        let selected = try? app.profiles.selectedProfile()
        let people = (try? app.profiles.people()) ?? []
        let groups = (try? app.profiles.groups()) ?? []
        NavigationStack {
            List {
                Section("People") {
                    ForEach(people) { row($0.profile, subtitle: nil, selected: selected) }
                }
                if !groups.isEmpty {
                    Section("Groups") {
                        ForEach(groups) { row($0.profile, subtitle: "\($0.memberCount) people", selected: selected) }
                    }
                }
            }
            .appListStyle()
            .navigationTitle("Who Are You Talking To?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { Button("Done") { dismiss() } }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func row(_ profile: Profile, subtitle: String?, selected: Profile?) -> some View {
        Button {
            try? app.profiles.select(profile.id)
            dismiss()
        } label: {
            HStack(spacing: 12) {
                AvatarView(emoji: profile.emoji)
                VStack(alignment: .leading) {
                    Text(profile.name).foregroundStyle(.primary)
                    if let subtitle { Text(subtitle).font(.footnote).foregroundStyle(.secondary) }
                }
                Spacer()
                if profile.id == selected?.id { Image(systemName: "checkmark").foregroundStyle(Color.accentColor) }
            }
        }
        .listRowBackground(Theme.surface)
        .accessibilityIdentifier("switch-\(profile.name)")
    }
}

struct DeckChoicesSheet: View {
    let app: Flashcards
    let profile: Profile
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            DeckChoicesList(app: app, profile: profile)
                .navigationTitle("Decks for \(profile.name)")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { Button("Done") { dismiss() } }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

struct DeckChoicesList: View {
    let app: Flashcards
    let profile: Profile
    @State private var errorMessage: String?

    var body: some View {
        let _ = app.database.revision
        let rows = (try? app.decks.rows(for: profile.id)) ?? []
        List {
            Section {
                ForEach(rows) { row in
                    Toggle(isOn: Binding(
                        get: { row.isOn },
                        set: { setDeck(row.id, on: $0) }
                    )) {
                        VStack(alignment: .leading) {
                            Text(row.deck.title)
                            Text("\(row.askedCount) of \(row.cardCount) asked").font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                    .listRowBackground(Theme.surface)
                    .accessibilityIdentifier("deck-toggle-\(row.id)")
                }
            } footer: {
                Text("At least one deck stays on.")
            }
        }
        .appListStyle()
        .errorAlert($errorMessage)
    }

    private func setDeck(_ id: String, on: Bool) {
        do { try app.decks.setDeck(id, on: on, for: profile.id) } catch { errorMessage = error.localizedDescription }
    }
}
