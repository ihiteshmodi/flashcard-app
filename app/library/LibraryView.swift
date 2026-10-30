import FlashcardsCore
import SwiftUI

struct LibraryView: View {
    let app: Flashcards
    @State private var editing: Card?
    @State private var isAdding = false
    @State private var deleting: Card?
    @State private var errorMessage: String?

    var body: some View {
        let _ = app.database.revision
        let mine = (try? app.customCards.cards()) ?? []
        let decks = (try? app.catalog.decks()) ?? []
        List {
            Section("My Cards") {
                if mine.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("No cards yet. Create your first card.").foregroundStyle(.secondary)
                        Button("New Card") { isAdding = true }.accessibilityIdentifier("empty-new-card")
                    }
                    .listRowBackground(Theme.surface)
                }
                ForEach(mine) { card in
                    Button { editing = card } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(card.prompt).foregroundStyle(.primary).multilineTextAlignment(.leading)
                            Text(subtitle(card)).font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                    .listRowBackground(Theme.surface)
                    .swipeActions {
                        Button("Delete", role: .destructive) { deleting = card }
                    }
                    .accessibilityIdentifier("my-card-\(card.prompt)")
                }
            }
            Section("Built-in Decks") {
                ForEach(decks) { summary in
                    NavigationLink {
                        DeckDetailView(app: app, summary: summary)
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(summary.deck.title)
                            Text(subtitle(summary)).font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                    .listRowBackground(Theme.surface)
                }
            }
        }
        .appListStyle()
        .navigationTitle("Library")
        .toolbar {
            Button("New Card") { isAdding = true }.accessibilityIdentifier("new-card")
        }
        .sheet(isPresented: $isAdding) { CardEditorSheet(app: app, card: nil) }
        .sheet(item: $editing) { CardEditorSheet(app: app, card: $0) }
        .confirmationDialog(deleteTitle, isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }), titleVisibility: .visible) {
            Button("Delete Card", role: .destructive) {
                if let deleting {
                    do { try app.customCards.delete(deleting.id) } catch { errorMessage = error.localizedDescription }
                }
                deleting = nil
            }
            Button("Cancel", role: .cancel) { deleting = nil }
        }
        .errorAlert($errorMessage)
    }

    private var deleteTitle: String {
        guard let deleting else { return "" }
        let lost = (try? app.customCards.answersLost(ifDeleting: deleting.id)) ?? 0
        return "Delete card and \(lost) \(lost == 1 ? "answer" : "answers")?"
    }

    private func subtitle(_ summary: DeckSummary) -> String {
        let categories = summary.categories.count
        return categories > 1 ? "\(summary.cardCount) cards · \(categories) categories" : "\(summary.cardCount) cards"
    }

    private func subtitle(_ card: Card) -> String {
        var parts = [kindLabel(card.kind)]
        if card.deckID != CustomCards.deckID, let deck = try? app.catalog.decks().first(where: { $0.id == card.deckID }) {
            parts.append(deck.deck.title)
        }
        if card.audience != .everyone { parts.append(card.audience.title) }
        if card.spice != .safe { parts.append(card.spice.title) }
        return parts.joined(separator: " · ")
    }

    private func kindLabel(_ kind: CardKind) -> String {
        switch kind {
        case .thisOrThat: return "This or That"
        case .multipleChoice: return "Multiple Choice"
        case .dare: return "Dare"
        default: return "Question"
        }
    }
}

struct DeckDetailView: View {
    let app: Flashcards
    let summary: DeckSummary

    var body: some View {
        let cards = (try? app.catalog.cards(in: summary.id)) ?? []
        let groups = Dictionary(grouping: cards) { $0.category ?? "" }
        let order = summary.categories.isEmpty ? [""] : (cards.contains { $0.category == nil } ? [""] : []) + summary.categories
        List {
            ForEach(order, id: \.self) { category in
                Section(category.isEmpty ? "Cards" : category) {
                    ForEach(groups[category] ?? []) { card in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(card.prompt)
                            if let detail = card.detail { Text(detail).font(.footnote).foregroundStyle(.secondary) }
                        }
                        .listRowBackground(Theme.surface)
                    }
                }
            }
        }
        .appListStyle()
        .navigationTitle(summary.deck.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct CardEditorSheet: View {
    let app: Flashcards
    let card: Card?
    @Environment(\.dismiss) private var dismiss
    @State private var kind = CardKind.question
    @State private var deckID = CustomCards.deckID
    @State private var prompt = ""
    @State private var category = ""
    @State private var detail = ""
    @State private var options = ["", ""]
    @State private var audience = Audience.everyone
    @State private var spice = Spice.safe
    @State private var perspective = Perspective.anyone
    @State private var errorMessage: String?

    private var deckChoices: [(id: String, title: String)] {
        [(CustomCards.deckID, "My Cards")] + ((try? app.catalog.decks()) ?? []).map { ($0.id, $0.deck.title) }
    }

    private var knownCategories: [String] {
        (try? app.customCards.categories(inDeck: deckID)) ?? []
    }

    var body: some View {
        NavigationStack {
            Form {
                if card == nil {
                    Picker("Kind", selection: $kind) {
                        Text("Question").tag(CardKind.question)
                        Text("This or That").tag(CardKind.thisOrThat)
                        Text("Multiple Choice").tag(CardKind.multipleChoice)
                        Text("Dare").tag(CardKind.dare)
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                    .accessibilityIdentifier("card-kind")
                }
                Section(kind == .question ? "Question" : "Prompt") {
                    TextField("What do you want to ask?", text: $prompt, axis: .vertical)
                        .lineLimit(2...6)
                        .accessibilityIdentifier("card-prompt")
                    TextField("Tip or detail (optional)", text: $detail, axis: .vertical)
                        .lineLimit(1...4)
                        .accessibilityIdentifier("card-detail")
                }
                .listRowBackground(Theme.surface)
                if kind.hasOptions {
                    Section(kind == .thisOrThat ? "Two Options" : "Options (2 to 4)") {
                        ForEach(options.indices, id: \.self) { index in
                            TextField("Option \(index + 1)", text: $options[index])
                                .accessibilityIdentifier("card-option-\(index)")
                        }
                        if kind == .multipleChoice && options.count < 4 {
                            Button("Add Option") { options.append("") }
                        }
                    }
                    .listRowBackground(Theme.surface)
                }
                Section("Where it goes") {
                    Picker("Deck", selection: $deckID) {
                        ForEach(deckChoices, id: \.id) { Text($0.title).tag($0.id) }
                    }
                    .accessibilityIdentifier("card-deck")
                    TextField("Category (optional)", text: $category)
                        .accessibilityIdentifier("card-category")
                    if !knownCategories.isEmpty {
                        Menu("Pick an existing category") {
                            ForEach(knownCategories, id: \.self) { name in
                                Button(name) { category = name }
                            }
                        }
                    }
                }
                .listRowBackground(Theme.surface)
                Section {
                    Picker("Who it's for", selection: $audience) {
                        ForEach(Audience.allCases, id: \.self) { Text($0.title).tag($0) }
                    }
                    .accessibilityIdentifier("card-audience")
                    Picker("How spicy", selection: $spice) {
                        ForEach(Spice.allCases, id: \.self) { Text($0.title).tag($0) }
                    }
                    .accessibilityIdentifier("card-spice")
                    Picker("Worded for", selection: $perspective) {
                        ForEach(Perspective.allCases, id: \.self) { Text($0.title).tag($0) }
                    }
                    .accessibilityIdentifier("card-perspective")
                } header: {
                    Text("Who sees it")
                } footer: {
                    Text("A card is shown to a person only when their gender and closeness fit these labels. The default, Everyone and Safe, is shown to everyone.")
                }
                .listRowBackground(Theme.surface)
                if let errorMessage {
                    Section { Text(errorMessage).foregroundStyle(.red).accessibilityIdentifier("form-error") }
                        .listRowBackground(Theme.surface)
                }
            }
            .appListStyle()
            .navigationTitle(card == nil ? "New Card" : "Edit Card")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(card == nil ? "Add" : "Save", action: save).accessibilityIdentifier("card-save")
                }
            }
            .onAppear(perform: load)
            .onChange(of: kind) { _, new in
                if new == .thisOrThat { options = Array(options.prefix(2)) }
                while options.count < 2 { options.append("") }
            }
        }
        .presentationDetents([.large])
    }

    private func load() {
        guard let card else { return }
        kind = card.kind
        deckID = card.deckID
        prompt = card.prompt
        category = card.category ?? ""
        detail = card.detail ?? ""
        options = card.options.isEmpty ? ["", ""] : card.options
        audience = card.audience
        spice = card.spice
        perspective = card.perspective
    }

    private func save() {
        do {
            if let card {
                try app.customCards.edit(
                    card.id, prompt: prompt, options: options, deckID: deckID, category: category, detail: detail,
                    audience: audience, spice: spice, perspective: perspective)
            } else {
                try app.customCards.add(
                    kind: kind, prompt: prompt, options: options, deckID: deckID, category: category, detail: detail,
                    audience: audience, spice: spice, perspective: perspective)
            }
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
