import XCTest
@testable import ALMS

final class SyncLinkRepositoryTests: XCTestCase {
    var db: ALMSDatabase!
    var repo: SyncLinkRepository!
    var itemId: String!

    override func setUp() {
        super.setUp()
        do {
            db = try TestDatabase.make()
            repo = SyncLinkRepository(db: db)

            let semesterRepo = SemesterRepository(db: db)
            let subjectRepo = SubjectRepository(db: db)
            let itemRepo = ItemRepository(db: db)
            var semester = Semester(id: UUID().uuidString, name: "S5", startDate: nil, endDate: nil,
                                    isActive: true, createdAt: now(), updatedAt: now())
            try semesterRepo.insert(&semester)
            let subject = Subject(id: UUID().uuidString, semesterId: semester.id, name: "ANN",
                                  code: "ANN", color: nil, archived: false, sortOrder: 0,
                                  createdAt: now(), updatedAt: now())
            try subjectRepo.insert(subject)
            let item = Item(id: UUID().uuidString, subjectId: subject.id, unitId: nil, categoryId: nil,
                            type: "assignment", title: "A1", description: nil, dueDate: "2025-06-20",
                            dueTime: nil, priority: "medium", source: nil,
                            status: "active", createdAt: now(), updatedAt: now())
            itemId = item.id
            try itemRepo.insert(item)
        } catch {
            XCTFail("Failed to set up test database: \(error)")
        }
    }

    func testInsertAndFetchReminderLink() throws {
        let link = makeReminderLink()
        try repo.upsertReminderLink(link)
        let fetched = try repo.fetchReminderLink(itemId: itemId)
        XCTAssertNotNil(fetched)
        XCTAssertEqual(fetched?.status, SyncStatus.pending.rawValue)
    }

    func testUpdateReminderLinkStatus() throws {
        try repo.upsertReminderLink(makeReminderLink())
        try repo.updateReminderLinkStatus(itemId: itemId, status: .created, error: nil)
        let fetched = try repo.fetchReminderLink(itemId: itemId)
        XCTAssertEqual(fetched?.status, SyncStatus.created.rawValue)
    }

    func testFetchFailedLinks() throws {
        try repo.upsertReminderLink(makeReminderLink())
        try repo.updateReminderLinkStatus(itemId: itemId, status: .failed, error: "timeout")
        let failed = try repo.fetchFailedReminderLinks()
        XCTAssertEqual(failed.count, 1)
        XCTAssertEqual(failed[0].errorMessage, "timeout")
    }

    private func makeReminderLink() -> ReminderLink {
        ReminderLink(id: UUID().uuidString, itemId: itemId, reminderExtId: nil,
                     reminderTitle: "ANN Assignment", listName: "ALMS",
                     status: SyncStatus.pending.rawValue, lastSyncedAt: nil,
                     errorMessage: nil, retryCount: 0, createdAt: now(), updatedAt: now())
    }

    private func now() -> String { ISO8601DateFormatter().string(from: Date()) }
}
