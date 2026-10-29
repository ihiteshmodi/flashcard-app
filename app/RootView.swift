import FlashcardsCore
import SwiftUI

struct RootView: View {
    let app: Flashcards

    var body: some View {
        TabView {
            CardsView(app: app)
                .tabItem { Label("Cards", systemImage: "rectangle.on.rectangle.angled") }
            NavigationStack { ProfilesView(app: app) }
                .tabItem { Label("Profiles", systemImage: "person.2") }
            NavigationStack { LibraryView(app: app) }
                .tabItem { Label("Library", systemImage: "books.vertical") }
            NavigationStack { SettingsView(app: app) }
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
        .toolbarBackground(Theme.background, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
    }
}
