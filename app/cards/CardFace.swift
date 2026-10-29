import FlashcardsCore
import SwiftUI

struct CardFace: View {
    let card: Card
    let deckTitle: String

    private var tag: String {
        [deckTitle, card.category].compactMap { $0 }.joined(separator: " · ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(tag)
                .font(.footnote.weight(.semibold))
                .textCase(.uppercase)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            Spacer(minLength: 0)
            content
            Spacer(minLength: 0)
            if let detail = card.detail, !detail.isEmpty {
                Divider()
                Text(detail)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, minHeight: 440, maxHeight: 480, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: 28, style: .continuous).fill(Theme.surface))
        .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).stroke(Color.primary.opacity(0.08), lineWidth: 0.5))
        .shadow(color: .black.opacity(0.12), radius: 16, y: 8)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("card-\(card.id)")
    }

    @ViewBuilder
    private var content: some View {
        switch card.kind {
        case .multipleChoice:
            VStack(alignment: .leading, spacing: 14) {
                Text(card.prompt).font(.title3.weight(.semibold))
                ForEach(Array(card.options.enumerated()), id: \.offset) { index, option in
                    HStack(alignment: .top, spacing: 12) {
                        Text(String(UnicodeScalar(UInt8(97 + index))))
                            .font(.caption.weight(.bold))
                            .frame(width: 22, height: 22)
                            .background(Circle().fill(Theme.raised))
                        Text(option).font(.body)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.primary.opacity(0.07)))
                }
            }
        case .thisOrThat:
            VStack(spacing: 10) {
                if !card.options.allSatisfy({ card.prompt.contains($0) }) {
                    Text(card.prompt).font(.title3.weight(.semibold)).frame(maxWidth: .infinity, alignment: .leading)
                }
                ForEach(Array(card.options.enumerated()), id: \.offset) { index, option in
                    if index > 0 {
                        Text("OR").font(.footnote.weight(.bold)).foregroundStyle(.secondary)
                    }
                    Text(option)
                        .font(.title3.weight(.semibold))
                        .multilineTextAlignment(.center)
                        .padding(16)
                        .frame(maxWidth: .infinity)
                        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.primary.opacity(0.07)))
                }
            }
        default:
            Text(card.prompt)
                .font(.system(size: 28, weight: .bold))
                .minimumScaleFactor(0.6)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
