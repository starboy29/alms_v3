import XCTest
@testable import ALMS

final class InboxServiceTests: XCTestCase {
    var db: ALMSDatabase!
    var bridge: MockShortcutsBridge!
    var service: InboxService!
    var subjectId: String!
    var tempDir: String!

    override func setUp() {
        super.setUp()
        do {
            db = try TestDatabase.make()
            bridge = MockShortcutsBridge()
            service = InboxService(db: db, bridge: bridge)

            tempDir = NSTemporaryDirectory() + "ALMSInboxTests-\(UUID().uuidString)"
            try FileManager.default.createDirectory(atPath: tempDir, withIntermediateDirectories: true)

            let settings = SettingsRepository(db: db)
            try settings.set(key: "root_folder", value: tempDir)

            let semRepo = SemesterRepository(db: db)
            let subRepo = SubjectRepository(db: db)
            var sem = Semester(id: UUID().uuidString, name: "S5", startDate: nil, endDate: nil,
                               isActive: true, createdAt: now(), updatedAt: now())
            try semRepo.insert(&sem)
            let sub = Subject(id: UUID().uuidString, semesterId: sem.id,
                              name: "ANN", code: "ANN", color: nil,
                              archived: false, sortOrder: 0, createdAt: now(), updatedAt: now())
            subjectId = sub.id
            try subRepo.insert(sub)
        } catch {
            XCTFail("setUp failed: \(error)")
        }
    }

    override func tearDown() {
        super.tearDown()
        try? FileManager.default.removeItem(atPath: tempDir)
    }

    func testSubmitTextWithHighConfidenceCreatesItem() throws {
        let result = try service.submitText("ANN Assignment 2 due 2025-06-20")
        XCTAssertFalse(result.needsConfirmation)
        XCTAssertFalse(result.itemId.isEmpty)

        let item = try ItemRepository(db: db).fetchById(result.itemId)
        XCTAssertNotNil(item)
        XCTAssertEqual(item?.type, ItemType.assignment.rawValue)
        XCTAssertEqual(item?.dueDate, "2025-06-20")
    }

    func testSubmitTextWithLowConfidenceNeedsConfirmation() throws {
        let result = try service.submitText("random stuff here")
        XCTAssertTrue(result.needsConfirmation)
        XCTAssertTrue(result.itemId.isEmpty)
    }

    func testSubmitTextCallsShortcutBridge() throws {
        _ = try service.submitText("ANN Assignment 2 due 2025-06-20")
        XCTAssertTrue(bridge.calls.contains { $0.name == "ALMS-CreateReminder" })
    }

    func testSubmitFileNotFoundThrows() throws {
        XCTAssertThrowsError(try service.submitFile("/nonexistent/path.pdf")) { error in
            guard case InboxError.fileNotFound = error else {
                XCTFail("Expected fileNotFound, got \(error)")
                return
            }
        }
    }

    func testSubmitFileWithConfirmedMetadata() throws {
        let srcPath = tempDir + "/ann_assignment.pdf"
        try "PDF content".write(toFile: srcPath, atomically: true, encoding: .utf8)

        let confirmed = ConfirmedMetadata(
            subjectId: subjectId, unitId: nil, categoryId: nil,
            type: .assignment, title: "ANN Assignment 1",
            dueDate: "2025-06-20", priority: .medium
        )

        let result = try service.submitFile(srcPath, confirmedMetadata: confirmed)
        XCTAssertFalse(result.needsConfirmation)
        XCTAssertFalse(result.itemId.isEmpty)

        XCTAssertFalse(FileManager.default.fileExists(atPath: srcPath))

        let item = try ItemRepository(db: db).fetchById(result.itemId)
        XCTAssertEqual(item?.title, "ANN Assignment 1")
    }

    private func now() -> String { ISO8601DateFormatter().string(from: Date()) }
}
