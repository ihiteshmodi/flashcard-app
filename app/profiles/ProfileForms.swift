import FlashcardsCore
import SwiftUI

struct ProfileFormSheet: View {
    enum Mode {
        case newPerson
        case rename(Profile)
    }

    let app: Flashcards
    let mode: Mode
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var emoji = ""
    @State private var gender: Gender?
    @State private var closeness = Closeness.friend
    @State private var errorMessage: String?

    private var isRename: Bool {
        if case .rename = mode { return true }
        return false
    }

    private var isGroup: Bool {
        if case .rename(let profile) = mode { return profile.kind == .group }
        return false
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $name)
                        .accessibilityIdentifier("profile-name")
                    if !isRename {
                        TextField("Emoji (optional)", text: $emoji)
                            .accessibilityIdentifier("profile-emoji")
                    }
                }
                .listRowBackground(Theme.surface)
                if !isGroup {
                    Section {
                        Picker("Gender", selection: $gender) {
                            Text("Not set").tag(Gender?.none)
                            ForEach(Gender.allCases, id: \.self) { Text($0.title).tag(Gender?.some($0)) }
                        }
                        .accessibilityIdentifier("profile-gender")
                        Picker("Closeness", selection: $closeness) {
                            ForEach(Closeness.allCases, id: \.self) { Text($0.title).tag($0) }
                        }
                        .pickerStyle(.segmented)
                        .accessibilityIdentifier("profile-closeness")
                    } footer: {
                        Text("Gender and closeness decide which cards this person is shown. Without a gender only everyday cards appear. You can change both any time.")
                    }
                    .listRowBackground(Theme.surface)
                }
                if let errorMessage {
                    Section { Text(errorMessage).foregroundStyle(.red).accessibilityIdentifier("form-error") }
                        .listRowBackground(Theme.surface)
                }
            }
            .appListStyle()
            .navigationTitle(isRename ? "Edit" : "New Person")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isRename ? "Save" : "Add", action: save).accessibilityIdentifier("profile-save")
                }
            }
            .onAppear {
                if case .rename(let profile) = mode {
                    name = profile.name
                    gender = profile.gender
                    closeness = profile.closeness
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func save() {
        do {
            switch mode {
            case .newPerson:
                try app.profiles.addPerson(name: name, emoji: String(emoji.prefix(2)), gender: gender, closeness: closeness)
            case .rename(let profile):
                try app.profiles.rename(profile.id, to: name)
                if profile.kind == .person {
                    try app.setGender(of: profile.id, to: gender)
                    try app.setCloseness(of: profile.id, to: closeness)
                }
            }
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct NewGroupSheet: View {
    let app: Flashcards
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var emoji = ""
    @State private var members: Set<String> = []
    @State private var errorMessage: String?

    var body: some View {
        let people = (try? app.profiles.people()) ?? []
        NavigationStack {
            Form {
                Section {
                    TextField("Group name", text: $name).accessibilityIdentifier("group-name")
                    TextField("Emoji (optional)", text: $emoji)
                }
                .listRowBackground(Theme.surface)
                Section {
                    ForEach(people) { summary in
                        Button {
                            if members.contains(summary.id) { members.remove(summary.id) } else { members.insert(summary.id) }
                        } label: {
                            HStack(spacing: 12) {
                                AvatarView(emoji: summary.profile.emoji)
                                Text(summary.profile.name).foregroundStyle(.primary)
                                Spacer()
                                Image(systemName: members.contains(summary.id) ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(members.contains(summary.id) ? Color.accentColor : .secondary)
                            }
                        }
                        .accessibilityIdentifier("member-\(summary.profile.name)")
                    }
                } header: {
                    Text("Members · \(members.count) selected")
                } footer: {
                    Text("Members are people you already added. A group keeps its own asked cards and answers. Nothing carries over between a group and its members.")
                }
                .listRowBackground(Theme.surface)
                if let errorMessage {
                    Section { Text(errorMessage).foregroundStyle(.red).accessibilityIdentifier("form-error") }
                        .listRowBackground(Theme.surface)
                }
            }
            .appListStyle()
            .navigationTitle("New Group")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create", action: create).accessibilityIdentifier("group-create")
                }
            }
        }
    }

    private func create() {
        do {
            try app.groups.createGroup(name: name, emoji: String(emoji.prefix(2)), memberIDs: Array(members))
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct AddMembersSheet: View {
    let app: Flashcards
    let group: Profile
    @Environment(\.dismiss) private var dismiss
    @State private var chosen: Set<String> = []

    var body: some View {
        let current = Set(((try? app.groups.members(of: group.id)) ?? []).map(\.id))
        let candidates = ((try? app.profiles.people()) ?? []).filter { !current.contains($0.id) }
        NavigationStack {
            List {
                if candidates.isEmpty {
                    Text("Everyone is already in this group.").foregroundStyle(.secondary)
                        .listRowBackground(Theme.surface)
                }
                ForEach(candidates) { summary in
                    Button {
                        if chosen.contains(summary.id) { chosen.remove(summary.id) } else { chosen.insert(summary.id) }
                    } label: {
                        HStack(spacing: 12) {
                            AvatarView(emoji: summary.profile.emoji)
                            Text(summary.profile.name).foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: chosen.contains(summary.id) ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(chosen.contains(summary.id) ? Color.accentColor : .secondary)
                        }
                    }
                    .listRowBackground(Theme.surface)
                    .accessibilityIdentifier("add-member-\(summary.profile.name)")
                }
            }
            .appListStyle()
            .navigationTitle("Add Members")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        try? app.groups.addMembers(Array(chosen), to: group.id)
                        dismiss()
                    }
                    .disabled(chosen.isEmpty)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
