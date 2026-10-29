import FlashcardsCore
import SwiftUI

struct NoteSheet: View {
    let app: Flashcards
    let profile: Profile
    let card: Card
    let title: String
    @Environment(\.dismiss) private var dismiss
    @State private var note = ""
    @State private var pick: Int?
    @State private var answeredBy = "Everyone"
    @State private var answerers: [String] = []
    @State private var errorMessage: String?
    @FocusState private var isEditing: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text(title).font(.headline)
                Text(card.prompt).font(.subheadline).foregroundStyle(.secondary)
                if profile.kind == .group { whoAnswered }
                if card.kind.hasOptions { options }
                noteField
                Button(action: save) {
                    Text("Save Answer").font(.headline).frame(maxWidth: .infinity).padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("save-answer")
                Button("Not Now") { dismiss() }
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier("not-now")
            }
            .padding(20)
        }
        .background(Theme.background.ignoresSafeArea())
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .errorAlert($errorMessage)
        .onAppear(perform: load)
    }

    private var whoAnswered: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Who answered?").font(.footnote).textCase(.uppercase).foregroundStyle(.secondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(answerers, id: \.self) { name in
                        Button { answeredBy = name } label: {
                            Text(name)
                                .font(.subheadline.weight(.semibold))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Capsule().fill(answeredBy == name ? Color.accentColor : Color.primary.opacity(0.1)))
                                .foregroundStyle(answeredBy == name ? Color.white : Color.primary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("answerer-\(name)")
                    }
                }
            }
        }
    }

    private var options: some View {
        VStack(spacing: 8) {
            ForEach(Array(card.options.enumerated()), id: \.offset) { index, option in
                Button { pick = pick == index ? nil : index } label: {
                    HStack(alignment: .top, spacing: 12) {
                        if card.kind == .multipleChoice {
                            Text(String(UnicodeScalar(UInt8(97 + index))))
                                .font(.caption.weight(.bold))
                                .frame(width: 22, height: 22)
                                .background(Circle().fill(pick == index ? Color.accentColor : Theme.raised))
                                .foregroundStyle(pick == index ? Color.white : Color.primary)
                        }
                        Text(option).multilineTextAlignment(.leading)
                        Spacer(minLength: 0)
                    }
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.primary.opacity(0.08)))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(pick == index ? Color.accentColor : .clear, lineWidth: 2))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("option-\(index)")
            }
        }
    }

    private var noteField: some View {
        TextField("Add a note…", text: $note, axis: .vertical)
            .lineLimit(3...8)
            .focused($isEditing)
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.primary.opacity(0.08)))
            .accessibilityIdentifier("answer-note")
    }

    private func load() {
        answerers = (try? app.answers.answerers(forGroup: profile.id)) ?? []
        if let existing = try? app.answers.answer(profileID: profile.id, cardID: card.id) {
            note = existing.text ?? ""
            pick = existing.pickIndex
            answeredBy = existing.answeredBy ?? "Everyone"
        }
        if !card.kind.hasOptions { isEditing = true }
    }

    private func save() {
        do {
            try app.answers.save(
                profileID: profile.id, cardID: card.id, text: note, pickIndex: pick,
                answeredBy: profile.kind == .group ? answeredBy : nil)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
