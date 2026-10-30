import FlashcardsCore
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    let app: Flashcards
    @AppStorage("appearance") private var appearance = Appearance.system.rawValue
    @State private var exportURL: URL?
    @State private var isSavingToFiles = false
    @State private var isSharing = false
    @State private var isPickingImport = false
    @State private var pendingImport: PendingImport?
    @State private var message: String?
    @State private var errorMessage: String?

    private struct PendingImport: Identifiable {
        let id = UUID()
        let url: URL
        let name: String
        let info: BackupInfo
    }

    var body: some View {
        let _ = app.database.revision
        let people = (try? app.profiles.people()) ?? []
        let groups = (try? app.profiles.groups()) ?? []
        let answers = (people + groups).reduce(0) { $0 + $1.answerCount }
        List {
            Section("Appearance") {
                Picker("Appearance", selection: $appearance) {
                    ForEach(Appearance.allCases) { Text($0.title).tag($0.rawValue) }
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
                .accessibilityIdentifier("appearance")
            }
            Section {
                Picker("I am", selection: Binding(
                    get: { (try? app.owner.gender()) ?? nil },
                    set: { new in
                        do { try app.setOwnerGender(new) } catch { errorMessage = error.localizedDescription }
                    })
                ) {
                    Text("Not set").tag(Gender?.none)
                    ForEach(Gender.allCases.reversed(), id: \.self) { Text($0.title).tag(Gender?.some($0)) }
                }
                .accessibilityIdentifier("i-am")
                .listRowBackground(Theme.surface)
            } header: {
                Text("About You")
            } footer: {
                Text("Some cards are worded from a man's or a woman's point of view. They only show when this matches.")
            }
            Section {
                Button("Save Export to Files…") { export(thenSave: true) }
                    .listRowBackground(Theme.surface)
                    .accessibilityIdentifier("export-files")
                Button("Share Export…") { export(thenSave: false) }
                    .listRowBackground(Theme.surface)
                    .accessibilityIdentifier("export-share")
                Button("Import Database…") { isPickingImport = true }
                    .listRowBackground(Theme.surface)
                    .accessibilityIdentifier("import-database")
            } header: {
                Text("Backup")
            } footer: {
                Text("Export saves one file, \(app.backup.suggestedFileName()), with all profiles, groups, decks chosen, asked cards, answers, your own cards and who you are. You choose where it goes. Import replaces everything after you confirm, and keeps a safety copy first.")
            }
            Section("Data") {
                row("Profiles", "\(people.count + groups.count)")
                row("Answers saved", "\(answers)")
                row("Last export", app.backup.lastExportedAt.map { $0.formatted(date: .abbreviated, time: .shortened) } ?? "Never")
            }
        }
        .appListStyle()
        .navigationTitle("Settings")
        .fileMover(isPresented: $isSavingToFiles, file: exportURL) { result in
            switch result {
            case .success: message = "Export saved."
            case .failure(let error): errorMessage = error.localizedDescription
            }
            cleanUpExport()
        }
        .sheet(isPresented: $isSharing, onDismiss: cleanUpExport) {
            if let exportURL { ShareSheet(items: [exportURL]) }
        }
        .fileImporter(isPresented: $isPickingImport, allowedContentTypes: [.data]) { result in
            handleImport(result)
        }
        .alert(
            "Replace All Current Data?",
            isPresented: Binding(get: { pendingImport != nil }, set: { if !$0 { discardImport() } }),
            presenting: pendingImport
        ) { pending in
            Button("Cancel", role: .cancel) { discardImport() }
            Button("Replace Data", role: .destructive) { restore(pending) }
        } message: { pending in
            Text("\(pending.name) has \(pending.info.profileCount) profiles and \(pending.info.answerCount) answers. A copy of the current data is kept first.")
        }
        .alert("Done", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(message ?? "")
        }
        .errorAlert($errorMessage)
    }

    private func row(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value).foregroundStyle(.secondary)
        }
        .listRowBackground(Theme.surface)
    }

    private func export(thenSave: Bool) {
        do {
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(app.backup.suggestedFileName())
            try app.backup.export(to: url)
            exportURL = url
            if thenSave { isSavingToFiles = true } else { isSharing = true }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func cleanUpExport() {
        if let exportURL { try? FileManager.default.removeItem(at: exportURL) }
        exportURL = nil
    }

    private func handleImport(_ result: Result<URL, Error>) {
        do {
            let picked = try result.get()
            let scoped = picked.startAccessingSecurityScopedResource()
            defer { if scoped { picked.stopAccessingSecurityScopedResource() } }
            let copy = FileManager.default.temporaryDirectory.appendingPathComponent("import-\(UUID().uuidString).sqlite")
            try FileManager.default.copyItem(at: picked, to: copy)
            do {
                pendingImport = PendingImport(url: copy, name: picked.lastPathComponent, info: try app.backup.inspect(copy))
            } catch {
                try? FileManager.default.removeItem(at: copy)
                throw error
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func restore(_ pending: PendingImport) {
        do {
            try app.backup.restore(from: pending.url)
            message = "Imported \(pending.info.profileCount) profiles and \(pending.info.answerCount) answers."
        } catch {
            errorMessage = error.localizedDescription
        }
        discardImport()
    }

    private func discardImport() {
        if let pendingImport { try? FileManager.default.removeItem(at: pendingImport.url) }
        pendingImport = nil
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
