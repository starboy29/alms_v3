import XCTest
@testable import ALMS

final class FinderServiceTests: XCTestCase {
    var db: ALMSDatabase!
    var service: FinderService!
    var tempDir: String!

    override func setUp() {
        super.setUp()
        do {
            db = try TestDatabase.make()
            tempDir = NSTemporaryDirectory() + "ALMSFinderTests-\(UUID().uuidString)"
            let settings = SettingsRepository(db: db)
            try settings.set(key: "root_folder", value: tempDir)
            service = FinderService(db: db)
        } catch {
            XCTFail("setUp failed: \(error)")
        }
    }

    override func tearDown() {
        super.tearDown()
        try? FileManager.default.removeItem(atPath: tempDir)
    }

    func testBuildPathWithAllComponents() throws {
        let path = try service.buildPath(
            semester: "Semester 5",
            subjectCode: "ANN",
            unitName: "Unit 1",
            categoryName: "Assignments"
        )
        XCTAssertTrue(path.hasSuffix("Semester5/ANN/Unit1/Assignments"), "Got: \(path)")
        XCTAssertTrue(path.hasPrefix(tempDir))
    }

    func testBuildPathSubjectOnly() throws {
        let path = try service.buildPath(subjectCode: "ML")
        XCTAssertTrue(path.hasSuffix("/ML"), "Got: \(path)")
    }

    func testEnsureFolderExistsCreatesNestedDirectories() throws {
        let path = tempDir + "/A/B/C"
        try service.ensureFolderExists(at: path)
        var isDir: ObjCBool = false
        XCTAssertTrue(FileManager.default.fileExists(atPath: path, isDirectory: &isDir))
        XCTAssertTrue(isDir.boolValue)
    }

    func testMoveFileMovesAndCreatesDestFolder() throws {
        try FileManager.default.createDirectory(atPath: tempDir, withIntermediateDirectories: true)
        let srcPath = tempDir + "/source.txt"
        try "test content".write(toFile: srcPath, atomically: true, encoding: .utf8)

        let destPath = tempDir + "/dest/folder/file.txt"
        let result = try service.moveFile(from: srcPath, to: destPath)

        XCTAssertEqual(result, destPath)
        XCTAssertTrue(FileManager.default.fileExists(atPath: destPath))
        XCTAssertFalse(FileManager.default.fileExists(atPath: srcPath))
    }

    func testFileExists() throws {
        try FileManager.default.createDirectory(atPath: tempDir, withIntermediateDirectories: true)
        let path = tempDir + "/test.txt"
        try "x".write(toFile: path, atomically: true, encoding: .utf8)
        XCTAssertTrue(service.fileExists(at: path))
        XCTAssertFalse(service.fileExists(at: tempDir + "/nonexistent.txt"))
    }
}
