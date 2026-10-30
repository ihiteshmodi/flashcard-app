import Foundation

/// The owner's own gender. It decides which cards worded from a man's or a woman's view are shown.
public final class Owner {
    let db: Database

    init(db: Database) { self.db = db }

    public func gender() throws -> Gender? {
        try db.setting(CardStates.ownerGenderKey).flatMap(Gender.init(rawValue:))
    }

    func setGender(_ gender: Gender?) throws {
        try db.setSetting(CardStates.ownerGenderKey, gender?.rawValue)
    }
}
