import Foundation
import GRDB

struct ItemRepository {
    private let db: ALMSDatabase

    init(db: ALMSDatabase) { self.db = db }

    func insert(_ item: Item) throws {
        var i = item
        try db.dbQueue.write { db in try i.insert(db) }
    }

    func update(_ item: Item) throws {
        var i = item
        try db.dbQueue.write { db in try i.update(db) }
    }

    func fetchById(_ id: String) throws -> Item? {
        try db.dbQueue.read { db in try Item.fetchOne(db, key: id) }
    }

    func fetchAll(
        subjectId: String? = nil,
        type: ItemType? = nil,
        status: ItemStatus = .active
    ) throws -> [Item] {
        try db.dbQueue.read { db in
            var request = Item.filter(Column("status") == status.rawValue)
            if let sid = subjectId {
                request = request.filter(Column("subject_id") == sid)
            }
            if let t = type {
                request = request.filter(Column("type") == t.rawValue)
            }
            return try request.order(Column("due_date")).fetchAll(db)
        }
    }

    func fetchDueBefore(_ dateString: String) throws -> [Item] {
        try db.dbQueue.read { db in
            try Item
                .filter(Column("due_date") != nil && Column("due_date") <= dateString)
                .filter(Column("status") == ItemStatus.active.rawValue)
                .order(Column("due_date"))
                .fetchAll(db)
        }
    }

    func fetchDueSoon(withinDays days: Int) throws -> [Item] {
        let startOfToday = Calendar.current.startOfDay(for: Date())
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: startOfToday) ?? startOfToday
        let cutoff = Calendar.current.date(byAdding: .day, value: days, to: startOfToday) ?? startOfToday
        let tomorrowStr = DateParser.iso8601Date(from: tomorrow)
        let cutoffStr = DateParser.iso8601Date(from: cutoff)
        return try db.dbQueue.read { db in
            try Item
                .filter(Column("due_date") != nil)
                .filter(Column("due_date") >= tomorrowStr)
                .filter(Column("due_date") <= cutoffStr)
                .filter(Column("status") == ItemStatus.active.rawValue)
                .order(Column("due_date"))
                .fetchAll(db)
        }
    }

    func archive(id: String) throws {
        try db.dbQueue.write { db in
            try db.execute(
                sql: "UPDATE items SET status = 'archived', updated_at = ? WHERE id = ?",
                arguments: [now(), id]
            )
        }
    }

    func complete(id: String) throws {
        try db.dbQueue.write { db in
            try db.execute(
                sql: "UPDATE items SET status = 'completed', updated_at = ? WHERE id = ?",
                arguments: [now(), id]
            )
        }
    }

    func archiveAll() throws {
        try db.dbQueue.write { db in
            try db.execute(
                sql: "UPDATE items SET status = 'archived', updated_at = ? WHERE status = 'active'",
                arguments: [now()]
            )
        }
    }

    private func now() -> String { ISO8601DateFormatter().string(from: Date()) }
}
