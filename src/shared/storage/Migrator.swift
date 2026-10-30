import Foundation

struct MigrationStep {
    let version: Int
    let apply: (Database) throws -> Void
}

struct Migrator {
    let steps: [MigrationStep]

    static let current = Migrator(steps: [
        MigrationStep(version: 1, apply: SchemaV1.apply),
        MigrationStep(version: 2, apply: SchemaV2.apply),
    ])

    var latestVersion: Int { steps.map(\.version).max() ?? 0 }

    func migrate(_ db: Database) throws {
        try db.transaction {
            let found = try db.schemaVersion()
            for step in steps.sorted(by: { $0.version < $1.version }) where step.version > found {
                try step.apply(db)
                try db.setSchemaVersion(step.version)
            }
        }
    }
}

/// Card labels (who it is for, how spicy, worded for) and the gender and closeness of each person.
enum SchemaV2 {
    static func apply(_ db: Database) throws {
        try db.script("""
        ALTER TABLE card ADD COLUMN audience TEXT NOT NULL DEFAULT 'everyone';
        ALTER TABLE card ADD COLUMN spice TEXT NOT NULL DEFAULT 'safe';
        ALTER TABLE card ADD COLUMN perspective TEXT NOT NULL DEFAULT 'anyone';
        ALTER TABLE profile ADD COLUMN gender TEXT;
        ALTER TABLE profile ADD COLUMN closeness TEXT NOT NULL DEFAULT 'friend';
        """)
    }
}

enum SchemaV1 {
    static func apply(_ db: Database) throws {
        try db.script("""
        CREATE TABLE deck(
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            sort_order INTEGER NOT NULL,
            is_builtin INTEGER NOT NULL
        );
        CREATE TABLE card(
            id TEXT PRIMARY KEY,
            deck_id TEXT NOT NULL REFERENCES deck(id) ON DELETE CASCADE,
            category TEXT,
            kind TEXT NOT NULL,
            prompt TEXT NOT NULL,
            detail TEXT,
            options TEXT NOT NULL DEFAULT '[]',
            sort_order INTEGER NOT NULL,
            is_builtin INTEGER NOT NULL,
            created_at REAL NOT NULL
        );
        CREATE TABLE profile(
            id TEXT PRIMARY KEY,
            kind TEXT NOT NULL CHECK(kind IN ('person','group')),
            name TEXT NOT NULL,
            emoji TEXT NOT NULL,
            name_key TEXT NOT NULL UNIQUE,
            created_at REAL NOT NULL
        );
        CREATE TABLE group_member(
            group_id TEXT NOT NULL REFERENCES profile(id) ON DELETE CASCADE,
            person_id TEXT NOT NULL REFERENCES profile(id) ON DELETE CASCADE,
            PRIMARY KEY(group_id, person_id)
        );
        CREATE TABLE profile_deck_off(
            profile_id TEXT NOT NULL REFERENCES profile(id) ON DELETE CASCADE,
            deck_id TEXT NOT NULL REFERENCES deck(id) ON DELETE CASCADE,
            PRIMARY KEY(profile_id, deck_id)
        );
        CREATE TABLE card_state(
            profile_id TEXT NOT NULL REFERENCES profile(id) ON DELETE CASCADE,
            card_id TEXT NOT NULL REFERENCES card(id) ON DELETE CASCADE,
            status TEXT NOT NULL CHECK(status IN ('asked','skipped')),
            updated_at REAL NOT NULL,
            PRIMARY KEY(profile_id, card_id)
        );
        CREATE TABLE answer(
            profile_id TEXT NOT NULL REFERENCES profile(id) ON DELETE CASCADE,
            card_id TEXT NOT NULL REFERENCES card(id) ON DELETE CASCADE,
            text TEXT,
            pick_index INTEGER,
            answered_by TEXT,
            updated_at REAL NOT NULL,
            PRIMARY KEY(profile_id, card_id)
        );
        CREATE TABLE setting(
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
        );
        INSERT INTO deck(id, title, sort_order, is_builtin) VALUES('my-cards', 'My Cards', 1000, 0);
        """)
    }
}
