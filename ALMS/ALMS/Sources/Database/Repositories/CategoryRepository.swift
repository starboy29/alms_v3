import Foundation
import GRDB

struct CategoryRepository {
    private let db: ALMSDatabase

    init(db: ALMSDatabase) { self.db = db }

    func insert(_ category: ALMSCategory) throws {
        var cat = category
        try db.dbQueue.write { db in try cat.insert(db) }
    }

    func fetchAll(unitId: String) throws -> [ALMSCategory] {
        try db.dbQueue.read { db in
            try ALMSCategory
                .filter(Column("unit_id") == unitId)
                .order(Column("sort_order"))
                .fetchAll(db)
        }
    }

    func createDefaultCategories(unitId: String) throws {
        let defaults: [(String, CategoryType)] = [
            ("Notes", .notes),
            ("Assignments", .assignment),
            ("Labs", .lab),
            ("PYQs", .pyq),
            ("Resources", .resource)
        ]
        let now = ISO8601DateFormatter().string(from: Date())
        try db.dbQueue.write { db in
            for (i, (name, type)) in defaults.enumerated() {
                var category = ALMSCategory(
                    id: UUID().uuidString,
                    unitId: unitId,
                    name: name,
                    type: type.rawValue,
                    sortOrder: i,
                    createdAt: now,
                    updatedAt: now
                )
                try? category.insert(db)
            }
        }
    }
}
