import XCTest
@testable import ALMS

final class ItemRepositoryTests: XCTestCase {
    var db: ALMSDatabase!
    var repo: ItemRepository!
    var subjectId: String!

    override func setUp() {
        super.setUp()
        do {
            db = try TestDatabase.make()
            repo = ItemRepository(db: db)

            let semesterRepo = SemesterRepository(db: db)
            let subjectRepo = SubjectRepository(db: db)
            var semester = Semester(id: UUID().uuidString, name: "S5", startDate: nil, endDate: nil,
                                    isActive: true, createdAt: now(), updatedAt: now())
            try semesterRepo.insert(&semester)
            let subject = Subject(id: UUID().uuidString, semesterId: semester.id, name: "ANN",
                                  code: "ANN", color: nil, archived: false, sortOrder: 0,
                                  createdAt: now(), updatedAt: now())
            subjectId = subject.id
            try subjectRepo.insert(subject)
        } catch {
            XCTFail("Failed to set up test database: \(error)")
        }
    }

    func testCreateAndFetch() throws {
        let item = makeItem(type: .assignment, title: "Assignment 2")
        try repo.insert(item)
        let fetched = try repo.fetchById(item.id)
        XCTAssertNotNil(fetched)
        XCTAssertEqual(fetched?.title, "Assignment 2")
    }

    func testFilterByType() throws {
        try repo.insert(makeItem(type: .assignment, title: "A1"))
        try repo.insert(makeItem(type: .exam, title: "E1"))
        let assignments = try repo.fetchAll(subjectId: subjectId, type: .assignment)
        XCTAssertEqual(assignments.count, 1)
        XCTAssertEqual(assignments[0].title, "A1")
    }

    func testFilterByDueBefore() throws {
        var item = makeItem(type: .assignment, title: "Due Soon")
        item.dueDate = "2025-06-20"
        try repo.insert(item)
        var item2 = makeItem(type: .assignment, title: "Due Later")
        item2.dueDate = "2025-09-01"
        try repo.insert(item2)
        let soon = try repo.fetchDueBefore("2025-07-01")
        XCTAssertEqual(soon.count, 1)
        XCTAssertEqual(soon[0].title, "Due Soon")
    }

    func testSoftDelete() throws {
        let item = makeItem(type: .assignment, title: "A1")
        try repo.insert(item)
        try repo.archive(id: item.id)
        let active = try repo.fetchAll(subjectId: subjectId, status: .active)
        XCTAssertTrue(active.isEmpty)
    }

    func testComplete() throws {
        let item = makeItem(type: .assignment, title: "A1")
        try repo.insert(item)
        try repo.complete(id: item.id)
        let fetched = try repo.fetchById(item.id)
        XCTAssertEqual(fetched?.status, ItemStatus.completed.rawValue)
    }

    private func makeItem(type: ItemType, title: String) -> Item {
        Item(id: UUID().uuidString, subjectId: subjectId, unitId: nil, categoryId: nil,
             type: type.rawValue, title: title, description: nil,
             dueDate: nil, dueTime: nil, priority: "medium", source: "test",
             status: "active", createdAt: now(), updatedAt: now())
    }

    private func now() -> String { ISO8601DateFormatter().string(from: Date()) }
}
