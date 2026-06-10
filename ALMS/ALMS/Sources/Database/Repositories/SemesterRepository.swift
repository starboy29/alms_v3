import Foundation
import GRDB

struct SemesterRepository {
    private let db: ALMSDatabase

    init(db: ALMSDatabase) {
        self.db = db
    }

    func insert(_ semester: inout Semester) throws {
        try db.dbQueue.write { db in
            try semester.insert(db)
        }
    }

    func fetchAll() throws -> [Semester] {
        try db.dbQueue.read { db in
            try Semester.fetchAll(db)
        }
    }

    func fetchActive() throws -> Semester? {
        try db.dbQueue.read { db in
            try Semester.filter(Column("is_active") == true).fetchOne(db)
        }
    }

    func fetchById(_ id: String) throws -> Semester? {
        try db.dbQueue.read { db in
            try Semester.fetchOne(db, key: id)
        }
    }

    func setActive(id: String) throws {
        try db.dbQueue.write { db in
            // Deactivate all
            try db.execute(sql: "UPDATE semesters SET is_active = 0, updated_at = ?",
                           arguments: [iso8601Now()])
            // Activate target
            try db.execute(sql: "UPDATE semesters SET is_active = 1, updated_at = ? WHERE id = ?",
                           arguments: [iso8601Now(), id])
        }
    }

    func update(_ semester: Semester) throws {
        try db.dbQueue.write { db in
            try semester.update(db)
        }
    }

    private func iso8601Now() -> String {
        ISO8601DateFormatter().string(from: Date())
    }
}
