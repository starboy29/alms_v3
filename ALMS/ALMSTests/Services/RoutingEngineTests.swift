import XCTest
@testable import ALMS

final class RoutingEngineTests: XCTestCase {
    var db: ALMSDatabase!
    var engine: RoutingEngine!
    var subjectId: String!

    override func setUp() {
        super.setUp()
        do {
            db = try TestDatabase.make()
            engine = RoutingEngine(db: db)

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

    func testAssignmentRoutesToReminderAndCalendar() throws {
        let item = makeItem(type: .assignment, dueDate: "2025-06-20")
        let targets = engine.route(item: item)
        let apps = targets.map { $0.app }
        XCTAssertTrue(apps.contains(.reminders))
        XCTAssertTrue(apps.contains(.calendar))
    }

    func testNotesTypeRoutesToReminders() throws {
        let item = makeItem(type: .notes, dueDate: nil)
        let targets = engine.route(item: item)
        XCTAssertEqual(targets.count, 1)
        XCTAssertEqual(targets[0].app, .reminders)
    }

    func testResourceTypeRoutesToNothing() throws {
        let item = makeItem(type: .resource, dueDate: nil)
        let targets = engine.route(item: item)
        XCTAssertTrue(targets.isEmpty)
    }

    func testPYQTypeRoutesToNothing() throws {
        let item = makeItem(type: .pyq, dueDate: nil)
        let targets = engine.route(item: item)
        XCTAssertTrue(targets.isEmpty)
    }

    func testEventTypeRoutesToCalendar() throws {
        let item = makeItem(type: .event, dueDate: "2025-07-01")
        let targets = engine.route(item: item)
        XCTAssertEqual(targets.count, 1)
        XCTAssertEqual(targets[0].app, .calendar)
    }

    func testAssignmentWithoutDueDateSkipsCalendar() throws {
        let item = makeItem(type: .assignment, dueDate: nil)
        let targets = engine.route(item: item)
        XCTAssertEqual(targets.count, 1)
        XCTAssertEqual(targets[0].app, .reminders)
    }

    private func makeItem(type: ItemType, dueDate: String?) -> Item {
        Item(id: UUID().uuidString, subjectId: subjectId, unitId: nil, categoryId: nil,
             type: type.rawValue, title: "Test Item", description: nil,
             dueDate: dueDate, dueTime: nil, priority: "medium", source: "test",
             status: "active", createdAt: now(), updatedAt: now())
    }

    private func now() -> String { ISO8601DateFormatter().string(from: Date()) }
}
