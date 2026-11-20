import FlashcardsCore
import SwiftUI

struct BlackCardView: View {
    let card: BlackCard

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(card.text)
                .font(.title3.weight(.bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
            Spacer(minLength: 0)
            if card.pick > 1 {
                Text("PICK \(card.pick)")
                    .font(.caption.weight(.heavy))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(.white))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, minHeight: 150, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Color.black))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Color.white.opacity(0.25), lineWidth: 1))
        .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("black-card")
    }
}

struct WhiteCardView: View {
    let text: String
    var badge: Int?
    var isSelected = false

    var body: some View {
        HStack(alignment: .top) {
            Text(text)
                .font(.body.weight(.semibold))
                .foregroundStyle(.black)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            if let badge {
                Text("\(badge)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 24, height: 24)
                    .background(Circle().fill(Color.accentColor))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 64, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.white))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(isSelected ? Color.accentColor : Color.black.opacity(0.12), lineWidth: isSelected ? 3 : 1))
        .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

struct ScoreList: View {
    let scoreboard: [Game.ScoreLine]

    var body: some View {
        ForEach(scoreboard, id: \.name) { line in
            HStack {
                Text(line.name)
                if line.isCzar {
                    Text("Czar").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                }
                Spacer()
                Text(line.points == 1 ? "1 point" : "\(line.points) points").foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("score-\(line.name)")
        }
    }
}

struct ScoresSheet: View {
    let scoreboard: [Game.ScoreLine]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List { ScoreList(scoreboard: scoreboard) }
                .appListStyle()
                .navigationTitle("Scores")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }.accessibilityIdentifier("scores-done")
                    }
                }
        }
        .presentationDetents([.medium, .large])
    }
}
