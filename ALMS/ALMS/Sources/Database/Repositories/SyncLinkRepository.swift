import Foundation
import GRDB

struct SyncLinkRepository {
    private let db: ALMSDatabase

    init(db: ALMSDatabase) { self.db = db }

    // MARK: - Reminder Links

    func upsertReminderLink(_ link: ReminderLink) throws {
        var l = link
        try db.dbQueue.write { db in try l.save(db) }
    }

    func fetchReminderLink(itemId: String) throws -> ReminderLink? {
        try db.dbQueue.read { db in
            try ReminderLink.filter(Column("item_id") == itemId).fetchOne(db)
        }
    }

    func updateReminderLinkStatus(itemId: String, status: SyncStatus, error: String?) throws {
        try db.dbQueue.write { db in
            try db.execute(
                sql: """
                    UPDATE reminder_links
                    SET status = ?, error_message = ?, last_synced_at = ?, updated_at = ?
                    WHERE item_id = ?
                """,
                arguments: [status.rawValue, error, now(), now(), itemId]
            )
        }
    }

    func fetchFailedReminderLinks(maxRetries: Int = 3) throws -> [ReminderLink] {
        try db.dbQueue.read { db in
            try ReminderLink
                .filter(Column("status") == SyncStatus.failed.rawValue)
                .filter(Column("retry_count") < maxRetries)
                .fetchAll(db)
        }
    }

    func incrementReminderRetry(itemId: String) throws {
        try db.dbQueue.write { db in
            try db.execute(
                sql: "UPDATE reminder_links SET retry_count = retry_count + 1, updated_at = ? WHERE item_id = ?",
                arguments: [now(), itemId]
            )
        }
    }

    // MARK: - Calendar Links

    func upsertCalendarLink(_ link: CalendarLink) throws {
        var l = link
        try db.dbQueue.write { db in try l.save(db) }
    }

    func fetchCalendarLink(itemId: String) throws -> CalendarLink? {
        try db.dbQueue.read { db in
            try CalendarLink.filter(Column("item_id") == itemId).fetchOne(db)
        }
    }

    func updateCalendarLinkStatus(itemId: String, status: SyncStatus, error: String?) throws {
        try db.dbQueue.write { db in
            try db.execute(
                sql: """
                    UPDATE calendar_links
                    SET status = ?, error_message = ?, last_synced_at = ?, updated_at = ?
                    WHERE item_id = ?
                """,
                arguments: [status.rawValue, error, now(), now(), itemId]
            )
        }
    }

    func fetchFailedCalendarLinks(maxRetries: Int = 3) throws -> [CalendarLink] {
        try db.dbQueue.read { db in
            try CalendarLink
                .filter(Column("status") == SyncStatus.failed.rawValue)
                .filter(Column("retry_count") < maxRetries)
                .fetchAll(db)
        }
    }

    // MARK: - Notes Links

    func upsertNotesLink(_ link: NotesLink) throws {
        var l = link
        try db.dbQueue.write { db in try l.save(db) }
    }

    func fetchNotesLink(itemId: String) throws -> NotesLink? {
        try db.dbQueue.read { db in
            try NotesLink.filter(Column("item_id") == itemId).fetchOne(db)
        }
    }

    func updateNotesLinkStatus(itemId: String, status: SyncStatus, error: String?) throws {
        try db.dbQueue.write { db in
            try db.execute(
                sql: """
                    UPDATE notes_links
                    SET status = ?, error_message = ?, last_synced_at = ?, updated_at = ?
                    WHERE item_id = ?
                """,
                arguments: [status.rawValue, error, now(), now(), itemId]
            )
        }
    }

    // MARK: - Cross-table queries

    func totalFailedCount() throws -> Int {
        try db.dbQueue.read { db in
            let r = try Int.fetchOne(db, sql: """
                SELECT COUNT(*) FROM (
                    SELECT id FROM reminder_links WHERE status = 'failed'
                    UNION ALL
                    SELECT id FROM calendar_links WHERE status = 'failed'
                    UNION ALL
                    SELECT id FROM notes_links WHERE status = 'failed'
                )
            """) ?? 0
            return r
        }
    }

    private func now() -> String { ISO8601DateFormatter().string(from: Date()) }
}
