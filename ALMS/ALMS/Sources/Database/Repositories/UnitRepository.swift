import Foundation
import GRDB

struct UnitRepository {
    private let db: ALMSDatabase

    init(db: ALMSDatabase) { self.db = db }

    func insert(_ unit: ALMSUnit) throws {
        var u = unit
        try db.dbQueue.write { db in try u.insert(db) }
    }

    func fetchAll(subjectId: String) throws -> [ALMSUnit] {
        try db.dbQueue.read { db in
            try ALMSUnit
                .filter(Column("subject_id") == subjectId)
                .order(Column("number"))
                .fetchAll(db)
        }
    }

    func fetchById(_ id: String) throws -> ALMSUnit? {
        try db.dbQueue.read { db in try ALMSUnit.fetchOne(db, key: id) }
    }

    func createDefaultUnits(subjectId: String, count: Int = 5) throws {
        let now = ISO8601DateFormatter().string(from: Date())
        try db.dbQueue.write { db in
            for i in 1...count {
                var unit = ALMSUnit(
                    id: UUID().uuidString,
                    subjectId: subjectId,
                    name: "Unit \(i)",
                    number: i,
                    createdAt: now,
                    updatedAt: now
                )
                try unit.insert(db)
            }
        }
    }
}
