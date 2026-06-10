import Foundation
import GRDB

struct SubjectRepository {
    private let db: ALMSDatabase

    init(db: ALMSDatabase) { self.db = db }

    func insert(_ subject: Subject) throws {
        var s = subject
        try db.dbQueue.write { db in try s.insert(db) }
    }

    func fetchAll(semesterId: String, includeArchived: Bool = false) throws -> [Subject] {
        try db.dbQueue.read { db in
            var request = Subject.filter(Column("semester_id") == semesterId)
            if !includeArchived {
                request = request.filter(Column("archived") == false)
            }
            return try request.order(Column("sort_order")).fetchAll(db)
        }
    }

    func fetchById(_ id: String) throws -> Subject? {
        try db.dbQueue.read { db in try Subject.fetchOne(db, key: id) }
    }

    func fetchByCode(_ code: String, semesterId: String) throws -> Subject? {
        try db.dbQueue.read { db in
            try Subject
                .filter(Column("code") == code && Column("semester_id") == semesterId)
                .fetchOne(db)
        }
    }

    func archive(id: String) throws {
        try db.dbQueue.write { db in
            try db.execute(
                sql: "UPDATE subjects SET archived = 1, updated_at = ? WHERE id = ?",
                arguments: [iso8601Now(), id]
            )
        }
    }

    func update(_ subject: Subject) throws {
        try db.dbQueue.write { db in try subject.update(db) }
    }

    func delete(id: String) throws {
        try db.dbQueue.write { db in
            try db.execute(sql: "DELETE FROM subjects WHERE id = ?", arguments: [id])
        }
    }

    private func iso8601Now() -> String { ISO8601DateFormatter().string(from: Date()) }
}
