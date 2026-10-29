import Foundation

extension Database {
    func setting(_ key: String) throws -> String? {
        try firstRow("SELECT value FROM setting WHERE key = ?1", [.text(key)])?.optionalString("value")
    }

    func setSetting(_ key: String, _ value: String?) throws {
        guard let value else {
            try run("DELETE FROM setting WHERE key = ?1", [.text(key)])
            return
        }
        try run(
            "INSERT INTO setting(key, value) VALUES(?1, ?2) ON CONFLICT(key) DO UPDATE SET value = excluded.value",
            [.text(key), .text(value)])
    }
}
