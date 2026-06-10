import Foundation
import GRDB

struct ActivityLogRepository {
    private let db: ALMSDatabase

    init(db: ALMSDatabase) { self.db = db }

    func log(
        eventType: LogEventType,
        entityType: String? = nil,
        entityId: String? = nil,
        details: String,
        errorMessage: String? = nil,
        metadata: [String: Any]? = nil
    ) {
        let metadataString: String? = metadata.flatMap {
            try? String(data: JSONSerialization.data(withJSONObject: $0), encoding: .utf8)
        }
        var entry = ActivityLog(
            id: UUID().uuidString,
            eventType: eventType.rawValue,
            entityType: entityType,
            entityId: entityId,
            details: details,
            errorMessage: errorMessage,
            metadata: metadataString,
            createdAt: ISO8601DateFormatter().string(from: Date())
        )
        try? db.dbQueue.write { db in try entry.insert(db) }
    }

    func fetchRecent(limit: Int = 50) throws -> [ActivityLog] {
        try db.dbQueue.read { db in
            try ActivityLog
                .order(Column("created_at").desc)
                .limit(limit)
                .fetchAll(db)
        }
    }

    func fetchByType(_ eventType: LogEventType, limit: Int = 100) throws -> [ActivityLog] {
        try db.dbQueue.read { db in
            try ActivityLog
                .filter(Column("event_type") == eventType.rawValue)
                .order(Column("created_at").desc)
                .limit(limit)
                .fetchAll(db)
        }
    }

    func countDuplicatesPrevented() throws -> Int {
        try db.dbQueue.read { db in
            try Int.fetchOne(db, sql: """
                SELECT COUNT(*) FROM activity_logs
                WHERE event_type = 'duplicate_prevented'
            """) ?? 0
        }
    }
}
