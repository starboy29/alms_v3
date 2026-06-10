import XCTest
import GRDB
@testable import ALMS

final class SemesterRepositoryTests: XCTestCase {
    var db: ALMSDatabase!
    var repo: SemesterRepository!

    override func setUp() {
        super.setUp()
        do {
            db = try TestDatabase.make()
            repo = SemesterRepository(db: db)
        } catch {
            XCTFail("Failed to set up test database: \(error)")
        }
    }

    func testInsertAndFetch() throws {
        var semester = makeSemester(name: "Semester 5")
        try repo.insert(&semester)
        let fetched = try repo.fetchAll()
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched[0].name, "Semester 5")
    }

    func testOnlyOneActiveSemesterAllowed() throws {
        var s1 = makeSemester(name: "Semester 4")
        var s2 = makeSemester(name: "Semester 5")
        s1.isActive = true
        s2.isActive = false
        try repo.insert(&s1)
        try repo.insert(&s2)
        try repo.setActive(id: s2.id)
        let active = try repo.fetchActive()
        XCTAssertEqual(active?.name, "Semester 5")
        let all = try repo.fetchAll()
        let activeCount = all.filter { $0.isActive }.count
        XCTAssertEqual(activeCount, 1)
    }

    func testFetchActiveReturnsNilWhenNoneActive() throws {
        var s = makeSemester(name: "Semester 5")
        try repo.insert(&s)
        let active = try repo.fetchActive()
        XCTAssertNil(active)
    }

    // MARK: - Helpers
    private func makeSemester(name: String) -> Semester {
        Semester(
            id: UUID().uuidString,
            name: name,
            startDate: nil,
            endDate: nil,
            isActive: false,
            createdAt: iso8601Now(),
            updatedAt: iso8601Now()
        )
    }

    private func iso8601Now() -> String {
        ISO8601DateFormatter().string(from: Date())
    }
}
