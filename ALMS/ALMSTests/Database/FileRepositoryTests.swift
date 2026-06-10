import XCTest
@testable import ALMS

final class FileRepositoryTests: XCTestCase {
    var db: ALMSDatabase!
    var repo: FileRepository!

    override func setUp() {
        super.setUp()
        do {
            db = try TestDatabase.make()
            repo = FileRepository(db: db)
        } catch {
            XCTFail("Failed to set up test database: \(error)")
        }
    }

    func testInsertAndFetchByHash() throws {
        let (file, hash) = makeFile(sha256: "abc123")
        try repo.insert(file: file, hash: hash)
        let found = try repo.findByHash("abc123")
        XCTAssertNotNil(found)
        XCTAssertEqual(found?.originalName, "test.pdf")
    }

    func testIsDuplicate() throws {
        let (file, hash) = makeFile(sha256: "abc123")
        try repo.insert(file: file, hash: hash)
        XCTAssertTrue(try repo.isDuplicate(sha256: "abc123"))
        XCTAssertFalse(try repo.isDuplicate(sha256: "different"))
    }

    func testMarkFinderUnverified() throws {
        let (file, hash) = makeFile(sha256: "abc123")
        try repo.insert(file: file, hash: hash)
        try repo.markUnverified(id: file.id)
        let fetched = try repo.fetchById(file.id)
        XCTAssertEqual(fetched?.finderVerified, false)
    }

    private func makeFile(sha256: String) -> (ALMSFile, FileHash) {
        let fileId = UUID().uuidString
        let file = ALMSFile(
            id: fileId, itemId: nil, originalName: "test.pdf",
            storedName: nil, storedPath: "/tmp/test.pdf",
            fileHash: sha256, fileSize: 1024, mimeType: "application/pdf",
            finderVerified: true, createdAt: now(), updatedAt: now()
        )
        let hash = FileHash(sha256: sha256, fileId: fileId, detectedAt: now())
        return (file, hash)
    }

    private func now() -> String { ISO8601DateFormatter().string(from: Date()) }
}
