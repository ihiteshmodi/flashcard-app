import FlashcardsCore
import SwiftUI

@main
struct FlashcardsApp: App {
    @State private var startup = CompositionRoot.start()
    @AppStorage("appearance") private var appearance = Appearance.system.rawValue

    var body: some Scene {
        WindowGroup {
            Group {
                switch startup {
                case .success(let app):
                    RootView(app: app)
                case .failure(let error):
                    ContentUnavailableView(
                        "Flashcards Could Not Start",
                        systemImage: "exclamationmark.triangle",
                        description: Text(error.localizedDescription))
                }
            }
            .preferredColorScheme(Appearance(rawValue: appearance)?.colorScheme)
        }
    }
}

enum Appearance: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}
