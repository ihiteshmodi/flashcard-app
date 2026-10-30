import Foundation
import XCTest
@testable import FlashcardsCore

/// Builds scenarios from domain words: people, groups, decks, cards.
final class World {
    let db: Database
    let app: Flashcards
    let roles: Roles

    init(shuffle: @escaping ([String]) -> [String] = { $0 }) throws {
        db = try Database.inMemory()
        var tick = 0
        var id = 0
        roles = Roles(
            now: {
                tick += 1
                return Date(timeIntervalSince1970: 1_700_000_000 + Double(tick))
            },
            shuffle: shuffle,
            newID: {
                id += 1
                return "id-\(id)"
            })
        app = try Flashcards(database: db, roles: roles)
    }

    @discardableResult
    func person(_ name: String) throws -> Profile {
        try app.profiles.addPerson(name: name)
    }

    @discardableResult
    func person(_ name: String, gender: Gender?, _ closeness: Closeness) throws -> Profile {
        try app.profiles.addPerson(name: name, gender: gender, closeness: closeness)
    }

    /// Sets the labels of a card that was created without any.
    func label(_ prompt: String, _ audience: Audience = .everyone, _ spice: Spice = .safe, _ perspective: Perspective = .anyone) throws {
        try db.run(
            "UPDATE card SET audience = ?2, spice = ?3, perspective = ?4 WHERE prompt = ?1",
            [.text(prompt), .text(audience.rawValue), .text(spice.rawValue), .text(perspective.rawValue)])
    }

    func stack(for profile: Profile) throws -> [String] {
        try app.session(for: profile.id).stack.map(\.prompt)
    }

    @discardableResult
    func deck(_ title: String, cards prompts: [String], kind: CardKind = .question, options: [String] = []) throws -> [Card] {
        let deckID = title.lowercased().replacingOccurrences(of: " ", with: "-")
        let order = try db.count("SELECT COUNT(*) AS n FROM deck")
        try db.run(
            "INSERT OR IGNORE INTO deck(id, title, sort_order, is_builtin) VALUES(?1, ?2, ?3, 1)",
            [.text(deckID), .text(title), .number(order)])
        var cards: [Card] = []
        for prompt in prompts {
            let number = try db.count("SELECT COUNT(*) AS n FROM card WHERE deck_id = ?1", [.text(deckID)]) + 1
            let id = "\(deckID)-\(number)"
            try db.run(
                """
                INSERT INTO card(id, deck_id, category, kind, prompt, detail, options, sort_order, is_builtin, created_at)
                VALUES(?1, ?2, NULL, ?3, ?4, NULL, ?5, ?6, 1, 0)
                """,
                [.text(id), .text(deckID), .text(kind.rawValue), .text(prompt),
                 .text(Card.encodeOptions(options)), .number(number)])
            cards.append(try card(id: id))
        }
        return cards
    }

    func card(id: String) throws -> Card {
        let row = try XCTUnwrap(try db.firstRow("SELECT * FROM card WHERE id = ?1", [.text(id)]))
        return Card(row: row)
    }

    func card(_ prompt: String) throws -> Card {
        let row = try XCTUnwrap(try db.firstRow("SELECT * FROM card WHERE prompt = ?1", [.text(prompt)]))
        return Card(row: row)
    }

    /// Marks cards asked straight in the database so profile tests do not depend on swiping.
    func markAsked(_ prompts: [String], for profile: Profile) throws {
        for prompt in prompts {
            let card = try card(prompt)
            try CardStates.set(db, profileID: profile.id, cardID: card.id, status: .asked, at: Date(timeIntervalSince1970: 1_600_000_000))
        }
    }

    func saveAnswerDirectly(_ text: String, card prompt: String, for profile: Profile) throws {
        let card = try card(prompt)
        try db.run(
            "INSERT INTO answer(profile_id, card_id, text, pick_index, answered_by, updated_at) VALUES(?1, ?2, ?3, NULL, NULL, 0)",
            [.text(profile.id), .text(card.id), .text(text)])
    }

    /// A second application over the same database, like relaunching the app.
    func relaunch() throws -> Flashcards {
        try Flashcards(database: db)
    }
}
