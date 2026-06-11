import XCTest
@testable import ALMS

final class InboxServiceTests: XCTestCase {
    var db: ALMSDatabase!
    var service: InboxService!
    var subjectId: String!
    var tempDir: String!

    override func setUp() {
        super.setUp()
        do {
            db = try TestDatabase.make()
            service = InboxService(db: db)

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

    func testSubmitTextWithHighConfidenceCreatesItem() async throws {
        let result = try await service.submitText("ANN Assignment 2 due 2025-06-20")
        XCTAssertFalse(result.needsConfirmation)
        XCTAssertFalse(result.itemId.isEmpty)

        let item = try ItemRepository(db: db).fetchById(result.itemId)
        XCTAssertNotNil(item)
        XCTAssertEqual(item?.type, ItemType.assignment.rawValue)
        XCTAssertEqual(item?.dueDate, "2025-06-20")
    }

    func testSubmitTextWithLowConfidenceNeedsConfirmation() async throws {
        let result = try await service.submitText("random stuff here")
        XCTAssertTrue(result.needsConfirmation)
        XCTAssertTrue(result.itemId.isEmpty)
    }

    func testSubmitFileNotFoundThrows() async {
        do {
            _ = try await service.submitFile("/nonexistent/path.pdf")
            XCTFail("Expected fileNotFound error")
        } catch InboxError.fileNotFound {
            // expected
        } catch {
            XCTFail("Expected fileNotFound, got \(error)")
        }
    }

    func testSubmitFileWithConfirmedMetadata() async throws {
        let srcPath = tempDir + "/ann_assignment.pdf"
        try "PDF content".write(toFile: srcPath, atomically: true, encoding: .utf8)

        let confirmed = ConfirmedMetadata(
            subjectId: subjectId, unitId: nil, categoryId: nil,
            type: .assignment, title: "ANN Assignment 1",
            dueDate: "2025-06-20", priority: .medium
        )

        let result = try await service.submitFile(srcPath, confirmedMetadata: confirmed)
        XCTAssertFalse(result.needsConfirmation)
        XCTAssertFalse(result.itemId.isEmpty)

        XCTAssertFalse(FileManager.default.fileExists(atPath: srcPath))

        let item = try ItemRepository(db: db).fetchById(result.itemId)
        XCTAssertEqual(item?.title, "ANN Assignment 1")
    }

    private func now() -> String { ISO8601DateFormatter().string(from: Date()) }
}
