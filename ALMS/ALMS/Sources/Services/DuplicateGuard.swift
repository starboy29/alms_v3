import Foundation
import GRDB

struct DuplicateCheckResult {
    let isDuplicate: Bool
    let existingItemId: String?
    let existingFileId: String?
}

struct DuplicateGuard {
    private let db: ALMSDatabase

    init(db: ALMSDatabase) { self.db = db }

    func checkFile(sha256: String) throws -> DuplicateCheckResult {
        let repo = FileRepository(db: db)
        guard try repo.isDuplicate(sha256: sha256) else {
            return DuplicateCheckResult(isDuplicate: false, existingItemId: nil, existingFileId: nil)
        }
        let file = try repo.findByHash(sha256)
        return DuplicateCheckResult(isDuplicate: true, existingItemId: file?.itemId, existingFileId: file?.id)
    }

    func checkReminder(subjectId: String, title: String, dueDate: String?) throws -> DuplicateCheckResult {
        let itemRepo = ItemRepository(db: db)
        let syncRepo = SyncLinkRepository(db: db)

        let items = try itemRepo.fetchAll(subjectId: subjectId, status: .active)
        guard let match = items.first(where: { item in
            item.title.lowercased() == title.lowercased() &&
            (dueDate == nil || item.dueDate == dueDate)
        }) else {
            return DuplicateCheckResult(isDuplicate: false, existingItemId: nil, existingFileId: nil)
        }

        let link = try syncRepo.fetchReminderLink(itemId: match.id)
        if link != nil {
            return DuplicateCheckResult(isDuplicate: true, existingItemId: match.id, existingFileId: nil)
        }
        return DuplicateCheckResult(isDuplicate: false, existingItemId: nil, existingFileId: nil)
    }

    func checkCalendarEvent(title: String, eventDate: String) throws -> DuplicateCheckResult {
        let count = try db.dbQueue.read { db in
            try Int.fetchOne(db, sql: """
                SELECT COUNT(*) FROM calendar_links
                WHERE event_title = ? AND event_date = ? AND status != 'failed'
            """, arguments: [title, eventDate]) ?? 0
        }
        return DuplicateCheckResult(isDuplicate: count > 0, existingItemId: nil, existingFileId: nil)
    }

    func checkNote(title: String, folderName: String) throws -> DuplicateCheckResult {
        let count = try db.dbQueue.read { db in
            try Int.fetchOne(db, sql: """
                SELECT COUNT(*) FROM notes_links
                WHERE note_title = ? AND folder_name = ? AND status != 'failed'
            """, arguments: [title, folderName]) ?? 0
        }
        return DuplicateCheckResult(isDuplicate: count > 0, existingItemId: nil, existingFileId: nil)
    }
}
