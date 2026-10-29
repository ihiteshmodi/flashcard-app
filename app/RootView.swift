import FlashcardsCore
import SwiftUI

struct RootView: View {
    let app: Flashcards

    var body: some View {
        NavigationStack {
            ProfilesView(app: app)
        }
    }
}

struct ProfilesView: View {
    let app: Flashcards
    @State private var isAdding = false
    @State private var name = ""
    @State private var errorMessage: String?

    var body: some View {
        let _ = app.database.revision
        let people = (try? app.profiles.people()) ?? []
        List {
            if people.isEmpty {
                ContentUnavailableView(
                    "No Profiles Yet", systemImage: "person.2",
                    description: Text("Add your first profile."))
            }
            ForEach(people) { summary in
                Text(summary.profile.name)
                    .accessibilityIdentifier("profile-row-\(summary.profile.name)")
            }
        }
        .navigationTitle("Profiles")
        .toolbar {
            Button("Add Person") { isAdding = true }
                .accessibilityIdentifier("add-person")
        }
        .alert("New Person", isPresented: $isAdding) {
            TextField("Name", text: $name)
                .accessibilityIdentifier("person-name")
            Button("Add") {
                do {
                    try app.profiles.addPerson(name: name)
                } catch {
                    errorMessage = error.localizedDescription
                }
                name = ""
            }
            Button("Cancel", role: .cancel) { name = "" }
        }
        .alert("Could Not Add", isPresented: Binding(get: { errorMessage != nil }, set: { _ in errorMessage = nil })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }
}
