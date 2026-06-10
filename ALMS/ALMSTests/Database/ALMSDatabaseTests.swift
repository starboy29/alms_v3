import XCTest
import GRDB
@testable import ALMS

final class ALMSDatabaseTests: XCTestCase {

    func testCanCreateInMemoryDatabase() throws {
        let db = try TestDatabase.make()
        XCTAssertNotNil(db)
    }

    func testAllTablesExist() throws {
        let db = try TestDatabase.make()
        let tables = try db.dbQueue.read { db in
            try Row.fetchAll(db, sql: "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'grdb_%' ORDER BY name")
                .map { $0["name"] as! String }
        }
        let expected = [
            "activity_logs", "calendar_links", "categories",
            "file_hashes", "files", "item_tags", "items",
            "notes_links", "reminder_links", "semesters",
            "settings", "subjects", "tags", "units"
        ]
        XCTAssertEqual(tables.sorted(), expected)
    }

    func testForeignKeysEnforced() throws {
        let db = try TestDatabase.make()
        try db.dbQueue.write { db in
            XCTAssertThrowsError(
                try db.execute(sql: """
                    INSERT INTO subjects
                      (id, semester_id, name, archived, sort_order, created_at, updated_at)
                    VALUES ('s1', 'nonexistent', 'Test', 0, 0, '2025-06-09T00:00:00Z', '2025-06-09T00:00:00Z')
                """),
                "Should throw FK violation"
            )
        }
    }

    func testRequiredIndexesExist() throws {
        let db = try TestDatabase.make()
        let indexes = try db.dbQueue.read { db in
            try Row.fetchAll(db, sql: "SELECT name FROM sqlite_master WHERE type='index' AND name NOT LIKE 'sqlite_%' ORDER BY name")
                .map { $0["name"] as! String }
        }
        let expected = [
            "idx_activity_logs_created",
            "idx_activity_logs_type",
            "idx_calendar_links_status",
            "idx_files_hash",
            "idx_files_item",
            "idx_items_due_date",
            "idx_items_status",
            "idx_items_subject",
            "idx_items_type",
            "idx_reminder_links_status",
            "idx_subjects_semester"
        ]
        for name in expected {
            XCTAssertTrue(indexes.contains(name), "Missing index: \(name)")
        }
    }
}
