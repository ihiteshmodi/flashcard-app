import Foundation

public struct Roles {
    public var now: () -> Date
    public var shuffle: ([String]) -> [String]
    public var newID: () -> String

    public init(now: @escaping () -> Date, shuffle: @escaping ([String]) -> [String], newID: @escaping () -> String) {
        self.now = now
        self.shuffle = shuffle
        self.newID = newID
    }

    public static var live: Roles {
        Roles(now: { Date() }, shuffle: { $0.shuffled() }, newID: { UUID().uuidString })
    }
}
