import FlashcardsCore
import SwiftUI

struct ProfileDetailView: View {
    let app: Flashcards
    let profileID: String
    @Environment(\.dismiss) private var dismiss
    @State private var tab = Tab.history
    @State private var onlyAnswered = false
    @State private var editing: HistoryEntry?
    @State private var isRenaming = false
    @State private var isAddingMembers = false
    @State private var isConfirmingDelete = false
    @State private var errorMessage: String?

    enum Tab: String, CaseIterable, Identifiable {
        case history = "History"
        case decks = "Decks"
        case members = "Members"
        var id: String { rawValue }
    }

    var body: some View {
        let _ = app.database.revision
        if let profile = try? app.profiles.profile(profileID) {
            let tabs = profile.kind == .group ? Tab.allCases : [.history, .decks]
            VStack(spacing: 8) {
                header(profile)
                Picker("Section", selection: $tab) {
                    ForEach(tabs) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .accessibilityIdentifier("profile-tabs")
                switch tab {
                case .history: history(profile)
                case .decks: DeckChoicesList(app: app, profile: profile)
                case .members: members(profile)
                }
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("\(profile.emoji) \(profile.name)")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                Menu {
                    Button("Use on Cards", systemImage: "checkmark") { try? app.profiles.select(profile.id) }
                    Button("Rename", systemImage: "pencil") { isRenaming = true }
                    Button("Delete Profile", systemImage: "trash", role: .destructive) { isConfirmingDelete = true }
                } label: {
                    Image(systemName: "ellipsis.circle").accessibilityLabel("More")
                }
            }
            .sheet(item: $editing) { entry in
                NoteSheet(app: app, profile: profile, card: entry.card, title: "Edit Answer")
            }
            .sheet(isPresented: $isRenaming) { ProfileFormSheet(app: app, mode: .rename(profile)) }
            .sheet(isPresented: $isAddingMembers) { AddMembersSheet(app: app, group: profile) }
            .confirmationDialog(deletionTitle(profile), isPresented: $isConfirmingDelete, titleVisibility: .visible) {
                Button("Delete Profile", role: .destructive) {
                    do {
                        try app.profiles.delete(profile.id)
                        dismiss()
                    } catch {
                        errorMessage = error.localizedDescription
                    }
                }
            }
            .errorAlert($errorMessage)
        } else {
            Color.clear.onAppear { dismiss() }
        }
    }

    private func header(_ profile: Profile) -> some View {
        let summary = ((try? app.profiles.people()) ?? []) + ((try? app.profiles.groups()) ?? [])
        let mine = summary.first { $0.id == profile.id }
        return Text(mine.map { "\($0.progress.asked) of \($0.progress.total) asked · \($0.answerCount) answers" } ?? "")
            .font(.footnote)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
    }

    private func history(_ profile: Profile) -> some View {
        let entries = (try? app.answers.history(profileID: profile.id, onlyWithAnswers: onlyAnswered)) ?? []
        return List {
            Section {
                Picker("Filter", selection: $onlyAnswered) {
                    Text("All Asked").tag(false)
                    Text("With Answers").tag(true)
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("history-filter")
            }
            .listRowBackground(Color.clear)
            Section {
                if entries.isEmpty {
                    Text(onlyAnswered ? "No saved answers yet." : "Nothing asked yet. Swipe a card right on the Cards tab.")
                        .foregroundStyle(.secondary)
                        .listRowBackground(Theme.surface)
                }
                ForEach(entries) { entry in
                    Button { editing = entry } label: { historyRow(entry) }
                        .listRowBackground(Theme.surface)
                        .accessibilityIdentifier("history-\(entry.card.id)")
                }
            } footer: {
                if !entries.isEmpty { Text("Tap an entry to edit the answer.") }
            }
        }
        .appListStyle()
    }

    private func historyRow(_ entry: HistoryEntry) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(entry.card.prompt).foregroundStyle(.primary).multilineTextAlignment(.leading)
            if let answer = entry.answer {
                let pick = answer.pickLabel(for: entry.card)
                let text = [pick, answer.text].compactMap { $0 }.joined(separator: " · ")
                let line = [answer.answeredBy, text].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: ": ")
                Text(line).font(.subheadline).foregroundStyle(Color.accentColor).multilineTextAlignment(.leading)
            }
            Text(entry.askedAt.formatted(date: .abbreviated, time: .omitted)).font(.caption).foregroundStyle(.secondary)
        }
    }

    private func members(_ profile: Profile) -> some View {
        let members = (try? app.groups.members(of: profile.id)) ?? []
        return List {
            Section {
                ForEach(members) { member in
                    HStack(spacing: 12) {
                        AvatarView(emoji: member.emoji)
                        Text(member.name)
                    }
                    .listRowBackground(Theme.surface)
                    .swipeActions {
                        Button("Remove", role: .destructive) {
                            do { try app.groups.removeMember(member.id, from: profile.id) } catch { errorMessage = error.localizedDescription }
                        }
                    }
                    .accessibilityIdentifier("member-row-\(member.name)")
                }
            } footer: {
                Text("Swipe a member left to remove them from this group. Their own profile and answers are not touched.")
            }
            Section {
                Button("Add Members…") { isAddingMembers = true }
                    .listRowBackground(Theme.surface)
                    .accessibilityIdentifier("add-members")
            }
        }
        .appListStyle()
    }

    private func deletionTitle(_ profile: Profile) -> String {
        let answers = (try? app.profiles.impactOfDeleting(profile.id).answers) ?? 0
        return "Delete \(profile.name) and \(answers) \(answers == 1 ? "answer" : "answers")?"
    }
}
