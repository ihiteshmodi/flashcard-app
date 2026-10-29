import Foundation
import Observation
import SQLite3

public enum DatabaseError: Error, LocalizedError, Equatable {
    case cannotOpen(String)
    case failed(String)

    public var errorDescription: String? {
        switch self {
        case .cannotOpen(let message): return "Cannot open the database: \(message)"
        case .failed(let message): return "Database error: \(message)"
        }
    }
}

enum SQLValue: Equatable, ExpressibleByStringLiteral, ExpressibleByIntegerLiteral, ExpressibleByNilLiteral, ExpressibleByFloatLiteral {
    case null
    case int(Int64)
    case real(Double)
    case text(String)

    init(stringLiteral value: String) { self = .text(value) }
    init(integerLiteral value: Int64) { self = .int(value) }
    init(floatLiteral value: Double) { self = .real(value) }
    init(nilLiteral: ()) { self = .null }

    static func optional(_ value: String?) -> SQLValue { value.map { .text($0) } ?? .null }
    static func optional(_ value: Int?) -> SQLValue { value.map { .int(Int64($0)) } ?? .null }
    static func number(_ value: Int) -> SQLValue { .int(Int64(value)) }
    static func date(_ value: Date) -> SQLValue { .real(value.timeIntervalSince1970) }
    static func flag(_ value: Bool) -> SQLValue { .int(value ? 1 : 0) }
}

struct Row {
    fileprivate let values: [String: SQLValue]

    func string(_ key: String) -> String {
        if case .text(let value) = values[key] { return value }
        return ""
    }

    func optionalString(_ key: String) -> String? {
        if case .text(let value) = values[key] { return value }
        return nil
    }

    func int(_ key: String) -> Int {
        switch values[key] {
        case .int(let value): return Int(value)
        case .real(let value): return Int(value)
        default: return 0
        }
    }

    func optionalInt(_ key: String) -> Int? {
        if case .int(let value) = values[key] { return Int(value) }
        return nil
    }

    func bool(_ key: String) -> Bool { int(key) != 0 }

    func date(_ key: String) -> Date {
        switch values[key] {
        case .real(let value): return Date(timeIntervalSince1970: value)
        case .int(let value): return Date(timeIntervalSince1970: Double(value))
        default: return Date(timeIntervalSince1970: 0)
        }
    }
}

/// Thin wrapper over one SQLite connection. `revision` changes on every write so views can refresh.
@Observable
public final class Database {
    @ObservationIgnored let handle: OpaquePointer
    @ObservationIgnored private var transactionDepth = 0
    public private(set) var revision = 0

    public init(path: String) throws {
        var opened: OpaquePointer?
        let flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX
        guard sqlite3_open_v2(path, &opened, flags, nil) == SQLITE_OK, let opened else {
            let message = opened.map { String(cString: sqlite3_errmsg($0)) } ?? "unknown error"
            if let opened { sqlite3_close(opened) }
            throw DatabaseError.cannotOpen(message)
        }
        handle = opened
        try run("PRAGMA foreign_keys = ON")
    }

    deinit { sqlite3_close(handle) }

    public static func inMemory() throws -> Database { try Database(path: ":memory:") }

    @discardableResult
    func run(_ sql: String, _ params: [SQLValue] = []) throws -> Int {
        let statement = try prepare(sql, params)
        defer { sqlite3_finalize(statement) }
        var code = sqlite3_step(statement)
        while code == SQLITE_ROW { code = sqlite3_step(statement) }
        guard code == SQLITE_DONE else { throw DatabaseError.failed(lastMessage) }
        if !sql.hasPrefix("PRAGMA") { revision += 1 }
        return Int(sqlite3_changes(handle))
    }

    func rows(_ sql: String, _ params: [SQLValue] = []) throws -> [Row] {
        let statement = try prepare(sql, params)
        defer { sqlite3_finalize(statement) }
        var result: [Row] = []
        let columnCount = sqlite3_column_count(statement)
        while true {
            let code = sqlite3_step(statement)
            if code == SQLITE_DONE { break }
            guard code == SQLITE_ROW else { throw DatabaseError.failed(lastMessage) }
            var values: [String: SQLValue] = [:]
            for index in 0..<columnCount {
                let name = String(cString: sqlite3_column_name(statement, index))
                switch sqlite3_column_type(statement, index) {
                case SQLITE_INTEGER: values[name] = .int(sqlite3_column_int64(statement, index))
                case SQLITE_FLOAT: values[name] = .real(sqlite3_column_double(statement, index))
                case SQLITE_TEXT: values[name] = .text(String(cString: sqlite3_column_text(statement, index)))
                default: values[name] = .null
                }
            }
            result.append(Row(values: values))
        }
        return result
    }

    func firstRow(_ sql: String, _ params: [SQLValue] = []) throws -> Row? {
        try rows(sql, params).first
    }

    func count(_ sql: String, _ params: [SQLValue] = []) throws -> Int {
        try firstRow(sql, params)?.int("n") ?? 0
    }

    func script(_ sql: String) throws {
        guard sqlite3_exec(handle, sql, nil, nil, nil) == SQLITE_OK else { throw DatabaseError.failed(lastMessage) }
        revision += 1
    }

    func transaction<T>(_ body: () throws -> T) throws -> T {
        if transactionDepth > 0 { return try body() }
        try run("BEGIN IMMEDIATE")
        transactionDepth += 1
        defer { transactionDepth -= 1 }
        do {
            let value = try body()
            try run("COMMIT")
            return value
        } catch {
            _ = try? run("ROLLBACK")
            throw error
        }
    }

    func schemaVersion() throws -> Int {
        try firstRow("PRAGMA user_version")?.int("user_version") ?? 0
    }

    func setSchemaVersion(_ version: Int) throws {
        try run("PRAGMA user_version = \(version)")
    }

    func tableNames() throws -> Set<String> {
        Set(try rows("SELECT name FROM sqlite_master WHERE type = 'table'").map { $0.string("name") })
    }

    private var lastMessage: String { String(cString: sqlite3_errmsg(handle)) }

    private func prepare(_ sql: String, _ params: [SQLValue]) throws -> OpaquePointer {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(handle, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
            throw DatabaseError.failed(lastMessage)
        }
        let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        for (offset, value) in params.enumerated() {
            let index = Int32(offset + 1)
            switch value {
            case .null: sqlite3_bind_null(statement, index)
            case .int(let number): sqlite3_bind_int64(statement, index, number)
            case .real(let number): sqlite3_bind_double(statement, index, number)
            case .text(let text): sqlite3_bind_text(statement, index, text, -1, transient)
            }
        }
        return statement
    }
}
