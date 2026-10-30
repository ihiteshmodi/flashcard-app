import FlashcardsCore
import SwiftUI

struct ProfilesView: View {
    let app: Flashcards
    @State private var isAddingPerson = false
    @State private var isAddingGroup = false
    @State private var renaming: Profile?
    @State private var deleting: Profile?
    @State private var deletionTitle = ""
    @State private var errorMessage: String?

    var body: some View {
        let _ = app.database.revision
        let selected = try? app.profiles.selectedProfile()
        let people = (try? app.profiles.people()) ?? []
        let groups = (try? app.profiles.groups()) ?? []
        List {
            if people.isEmpty && groups.isEmpty {
                ContentUnavailableView(
                    "No Profiles Yet", systemImage: "person.2",
                    description: Text("Add your first profile."))
                    .listRowBackground(Color.clear)
            }
            if !people.isEmpty {
                Section("People") { ForEach(people) { row($0, selected: selected) } }
            }
            if !groups.isEmpty {
                Section("Groups") { ForEach(groups) { row($0, selected: selected) } }
            }
            if !people.isEmpty || !groups.isEmpty {
                Section {} footer: {
                    Text("The checkmark shows who the Cards tab is using. Swipe a row to delete it. People and groups are tracked separately.")
                }
            }
        }
        .appListStyle()
        .navigationTitle("Profiles")
        .navigationDestination(for: String.self) { ProfileDetailView(app: app, profileID: $0) }
        .toolbar {
            Menu {
                Button("New Person", systemImage: "person.badge.plus") { isAddingPerson = true }
                    .accessibilityIdentifier("new-person")
                Button("New Group", systemImage: "person.3") { isAddingGroup = true }
                    .accessibilityIdentifier("new-group")
                    .disabled(people.isEmpty)
            } label: {
                Image(systemName: "plus").accessibilityLabel("Add")
            }
            .accessibilityIdentifier("add-profile")
        }
        .sheet(isPresented: $isAddingPerson) { ProfileFormSheet(app: app, mode: .newPerson) }
        .sheet(isPresented: $isAddingGroup) { NewGroupSheet(app: app) }
        .sheet(item: $renaming) { ProfileFormSheet(app: app, mode: .rename($0)) }
        .confirmationDialog(deletionTitle, isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }), titleVisibility: .visible) {
            Button("Delete Profile", role: .destructive) {
                if let deleting {
                    do { try app.profiles.delete(deleting.id) } catch { errorMessage = error.localizedDescription }
                }
                deleting = nil
            }
            Button("Cancel", role: .cancel) { deleting = nil }
        }
        .errorAlert($errorMessage)
    }

    private func row(_ summary: ProfileSummary, selected: Profile?) -> some View {
        let profile = summary.profile
        var parts: [String] = []
        if let tags = profile.tagSummary { parts.append(tags) }
        if profile.kind == .group { parts.append("\(summary.memberCount) people") }
        parts.append("\(summary.progress.asked) of \(summary.progress.total) asked")
        if summary.answerCount > 0 { parts.append("\(summary.answerCount) answers") }
        return NavigationLink(value: profile.id) {
            HStack(spacing: 12) {
                AvatarView(emoji: profile.emoji)
                VStack(alignment: .leading, spacing: 2) {
                    Text(profile.name)
                    Text(parts.joined(separator: " · ")).font(.footnote).foregroundStyle(.secondary)
                }
                Spacer()
                if profile.id == selected?.id {
                    Image(systemName: "checkmark").foregroundStyle(Color.accentColor).accessibilityLabel("In use on Cards")
                }
            }
        }
        .listRowBackground(Theme.surface)
        .accessibilityIdentifier("profile-row-\(profile.name)")
        .swipeActions(edge: .trailing) {
            Button("Delete", role: .destructive) { askToDelete(profile) }
        }
        .contextMenu {
            Button("Use on Cards", systemImage: "checkmark") { try? app.profiles.select(profile.id) }
            Button("Edit", systemImage: "pencil") { renaming = profile }
        }
    }

    private func askToDelete(_ profile: Profile) {
        let impact = try? app.profiles.impactOfDeleting(profile.id)
        let answers = impact?.answers ?? 0
        deletionTitle = "Delete \(profile.name) and \(answers) \(answers == 1 ? "answer" : "answers")?"
        deleting = profile
    }
}
