import XCTest
@testable import ALMS

final class SubjectRepositoryTests: XCTestCase {
    var db: ALMSDatabase!
    var semesterRepo: SemesterRepository!
    var repo: SubjectRepository!
    var semesterId: String!

    override func setUp() {
        super.setUp()
        do {
            db = try TestDatabase.make()
            semesterRepo = SemesterRepository(db: db)
            repo = SubjectRepository(db: db)
            var semester = Semester(
                id: UUID().uuidString, name: "Semester 5",
                startDate: nil, endDate: nil, isActive: true,
                createdAt: iso8601Now(), updatedAt: iso8601Now()
            )
            semesterId = semester.id
            try semesterRepo.insert(&semester)
        } catch {
            XCTFail("Failed to set up test database: \(error)")
        }
    }

    func testInsertAndFetchBySemester() throws {
        let s = makeSubject(name: "ANN", code: "ANN")
        try repo.insert(s)
        let fetched = try repo.fetchAll(semesterId: semesterId)
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched[0].code, "ANN")
    }

    func testFetchByCode() throws {
        try repo.insert(makeSubject(name: "ANN", code: "ANN"))
        let found = try repo.fetchByCode("ANN", semesterId: semesterId)
        XCTAssertNotNil(found)
    }

    func testArchiveSubject() throws {
        let s = makeSubject(name: "ANN", code: "ANN")
        try repo.insert(s)
        try repo.archive(id: s.id)
        let fetched = try repo.fetchAll(semesterId: semesterId, includeArchived: false)
        XCTAssertTrue(fetched.isEmpty)
        let all = try repo.fetchAll(semesterId: semesterId, includeArchived: true)
        XCTAssertEqual(all.count, 1)
        XCTAssertTrue(all[0].archived)
    }

    func testDuplicateNameWithinSemesterFails() throws {
        try repo.insert(makeSubject(name: "ANN", code: "ANN"))
        XCTAssertThrowsError(
            try repo.insert(makeSubject(name: "ANN", code: "ANN2")),
            "Duplicate name in same semester should fail"
        )
    }

    private func makeSubject(name: String, code: String) -> Subject {
        Subject(
            id: UUID().uuidString, semesterId: semesterId,
            name: name, code: code, color: nil,
            archived: false, sortOrder: 0,
            createdAt: iso8601Now(), updatedAt: iso8601Now()
        )
    }

    private func iso8601Now() -> String { ISO8601DateFormatter().string(from: Date()) }
}
