import XCTest
@testable import ALMS

final class DuplicateGuardTests: XCTestCase {
    var db: ALMSDatabase!
    var guard_: DuplicateGuard!
    var subjectId: String!

    override func setUp() {
        super.setUp()
        do {
            db = try TestDatabase.make()
            guard_ = DuplicateGuard(db: db)

            let semRepo = SemesterRepository(db: db)
            let subRepo = SubjectRepository(db: db)
            var sem = Semester(id: UUID().uuidString, name: "S5", startDate: nil, endDate: nil,
                               isActive: true, createdAt: now(), updatedAt: now())
            try semRepo.insert(&sem)
            let sub = Subject(id: UUID().uuidString, semesterId: sem.id, name: "ANN",
                              code: "ANN", color: nil, archived: false, sortOrder: 0,
                              createdAt: now(), updatedAt: now())
            subjectId = sub.id
            try subRepo.insert(sub)
        } catch {
            XCTFail("setUp failed: \(error)")
        }
    }

    func testFileNotDuplicateWhenHashAbsent() throws {
        let result = try guard_.checkFile(sha256: "abc123")
        XCTAssertFalse(result.isDuplicate)
    }

    func testFileIsDuplicateAfterInsert() throws {
        let fileRepo = FileRepository(db: db)
        let fileId = UUID().uuidString
        let file = ALMSFile(id: fileId, itemId: nil, originalName: "test.pdf",
                            storedName: nil, storedPath: "/tmp/test.pdf",
                            fileHash: "abc123", fileSize: 1024, mimeType: nil,
                            finderVerified: true, createdAt: now(), updatedAt: now())
        let hash = FileHash(sha256: "abc123", fileId: fileId, detectedAt: now())
        try fileRepo.insert(file: file, hash: hash)

        let result = try guard_.checkFile(sha256: "abc123")
        XCTAssertTrue(result.isDuplicate)
        XCTAssertEqual(result.existingFileId, fileId)
    }

    func testReminderNotDuplicateForNewItem() throws {
        let result = try guard_.checkReminder(subjectId: subjectId, title: "Assignment 2", dueDate: nil)
        XCTAssertFalse(result.isDuplicate)
    }

    func testCalendarEventNotDuplicate() throws {
        let result = try guard_.checkCalendarEvent(title: "ANN Exam", eventDate: "2025-06-20")
        XCTAssertFalse(result.isDuplicate)
    }

    func testCalendarEventIsDuplicateAfterInsert() throws {
        let itemRepo = ItemRepository(db: db)
        let syncRepo = SyncLinkRepository(db: db)
        let item = Item(id: UUID().uuidString, subjectId: subjectId, unitId: nil, categoryId: nil,
                        type: "exam", title: "ANN Exam", description: nil, dueDate: "2025-06-20",
                        dueTime: nil, priority: "medium", source: nil,
                        status: "active", createdAt: now(), updatedAt: now())
        try itemRepo.insert(item)
        let link = CalendarLink(id: UUID().uuidString, itemId: item.id, eventExtId: nil,
                                eventTitle: "ANN Exam", calendarName: "ALMS",
                                eventDate: "2025-06-20", allDay: true,
                                status: SyncStatus.created.rawValue,
                                lastSyncedAt: nil, errorMessage: nil, retryCount: 0,
                                createdAt: now(), updatedAt: now())
        try syncRepo.upsertCalendarLink(link)

        let result = try guard_.checkCalendarEvent(title: "ANN Exam", eventDate: "2025-06-20")
        XCTAssertTrue(result.isDuplicate)
    }

    private func now() -> String { ISO8601DateFormatter().string(from: Date()) }
}
