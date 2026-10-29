import Foundation

public final class Groups {
    let db: Database
    let profiles: Profiles

    init(db: Database, profiles: Profiles) {
        self.db = db
        self.profiles = profiles
    }

    /// A group tracks its own asked cards and answers; members are only listed.
    @discardableResult
    public func createGroup(name: String, emoji: String = "👥", memberIDs: [String]) throws -> Profile {
        try db.transaction {
            let group = try profiles.create(kind: .group, name: name, emoji: emoji)
            guard !memberIDs.isEmpty else { throw ProfileError.noMembers }
            try addMembers(memberIDs, to: group.id)
            return group
        }
    }

    public func members(of groupID: String) throws -> [Profile] {
        try db.rows(
            """
            SELECT profile.* FROM group_member
            JOIN profile ON profile.id = group_member.person_id
            WHERE group_member.group_id = ?1
            ORDER BY profile.name_key
            """, [.text(groupID)]).map(Profile.init(row:))
    }

    public func addMembers(_ personIDs: [String], to groupID: String) throws {
        try db.transaction {
            for id in personIDs {
                try db.run(
                    """
                    INSERT OR IGNORE INTO group_member(group_id, person_id)
                    SELECT ?1, id FROM profile WHERE id = ?2 AND kind = 'person'
                    """, [.text(groupID), .text(id)])
            }
        }
    }

    public func removeMember(_ personID: String, from groupID: String) throws {
        let current = try members(of: groupID)
        guard current.contains(where: { $0.id == personID }) else { return }
        guard current.count > 1 else { throw ProfileError.lastMember }
        try db.run(
            "DELETE FROM group_member WHERE group_id = ?1 AND person_id = ?2",
            [.text(groupID), .text(personID)])
    }
}
