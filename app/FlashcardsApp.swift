import FlashcardsCore
import SwiftUI

@main
struct FlashcardsApp: App {
    @State private var startup = CompositionRoot.start()

    var body: some Scene {
        WindowGroup {
            switch startup {
            case .success(let app):
                RootView(app: app)
            case .failure(let error):
                StartupFailureView(message: error.localizedDescription)
            }
        }
    }
}

private struct StartupFailureView: View {
    let message: String

    var body: some View {
        ContentUnavailableView(
            "Flashcards Could Not Start",
            systemImage: "exclamationmark.triangle",
            description: Text(message))
    }
}
