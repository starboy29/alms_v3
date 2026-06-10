import XCTest
@testable import ALMS

final class SettingsRepositoryTests: XCTestCase {
    var db: ALMSDatabase!
    var repo: SettingsRepository!

    override func setUp() {
        super.setUp()
        do {
            db = try TestDatabase.make()
            repo = SettingsRepository(db: db)
        } catch {
            XCTFail("Failed to set up test database: \(error)")
        }
    }

    func testSetAndGetString() throws {
        try repo.set(key: "root_folder", value: "/tmp/alms")
        let value = try repo.getString(key: "root_folder")
        XCTAssertEqual(value, "/tmp/alms")
    }

    func testGetWithDefaultWhenMissing() throws {
        let value = try repo.getString(key: "missing_key", default: "fallback")
        XCTAssertEqual(value, "fallback")
    }

    func testSetAndGetBool() throws {
        try repo.set(key: "file_renaming_enabled", value: true)
        let value = try repo.getBool(key: "file_renaming_enabled")
        XCTAssertEqual(value, true)
    }

    func testOverwrite() throws {
        try repo.set(key: "root_folder", value: "/tmp/v1")
        try repo.set(key: "root_folder", value: "/tmp/v2")
        let value = try repo.getString(key: "root_folder")
        XCTAssertEqual(value, "/tmp/v2")
    }
}

final class ActivityLogRepositoryTests: XCTestCase {
    func testLogAndFetch() throws {
        let db = try TestDatabase.make()
        let repo = ActivityLogRepository(db: db)
        repo.log(eventType: .`import`, details: "Imported test.pdf")
        let recent = try repo.fetchRecent(limit: 10)
        XCTAssertEqual(recent.count, 1)
        XCTAssertEqual(recent[0].eventType, "import")
    }
}
