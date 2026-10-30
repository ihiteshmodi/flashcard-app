import Foundation

public enum Audience: String, Codable, CaseIterable {
    case everyone
    case women
    case men
    case couples

    public var title: String {
        switch self {
        case .everyone: return "Everyone"
        case .women: return "Women"
        case .men: return "Men"
        case .couples: return "Couples"
        }
    }
}

public enum Spice: String, Codable, CaseIterable {
    case safe
    case flirty
    case explicit

    public var title: String { rawValue.capitalized }
}

/// The asker's point of view a card is worded in, for example "Do you like it when I wear cologne?".
public enum Perspective: String, Codable, CaseIterable {
    case anyone
    case man
    case woman

    public var title: String {
        switch self {
        case .anyone: return "Anyone"
        case .man: return "A man's view"
        case .woman: return "A woman's view"
        }
    }
}

public enum Gender: String, Codable, CaseIterable {
    case woman
    case man

    public var title: String { rawValue.capitalized }
}

public enum Closeness: String, Codable, CaseIterable {
    case friend
    case dating
    case partner

    public var title: String { rawValue.capitalized }
}

/// Which labels a profile may be shown. Groups and people without a gender tag only see Everyone, Safe cards.
struct Eligibility: Equatable {
    let audiences: [Audience]
    let spices: [Spice]
    let perspectives: [Perspective]

    init(gender: Gender?, closeness: Closeness, isGroup: Bool, owner: Gender?) {
        let tagged = !isGroup && gender != nil
        var audiences: [Audience] = [.everyone]
        var spices: [Spice] = [.safe]
        if tagged {
            audiences.append(gender == .woman ? .women : .men)
            if closeness != .friend {
                audiences.append(.couples)
                spices.append(.flirty)
            }
            if closeness == .partner { spices.append(.explicit) }
        }
        var perspectives: [Perspective] = [.anyone]
        if owner == .man { perspectives.append(.man) }
        if owner == .woman { perspectives.append(.woman) }
        self.audiences = audiences
        self.spices = spices
        self.perspectives = perspectives
    }

    func allows(_ card: Card) -> Bool {
        audiences.contains(card.audience) && spices.contains(card.spice) && perspectives.contains(card.perspective)
    }

    /// Built from enum raw values only, so it is safe to splice into SQL.
    var sqlCondition: String {
        func list<T: RawRepresentable>(_ values: [T]) -> String where T.RawValue == String {
            values.map { "'\($0.rawValue)'" }.joined(separator: ", ")
        }
        return "card.audience IN (\(list(audiences))) AND card.spice IN (\(list(spices))) AND card.perspective IN (\(list(perspectives)))"
    }
}
