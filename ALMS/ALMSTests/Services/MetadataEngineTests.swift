import XCTest
@testable import ALMS

final class MetadataEngineTests: XCTestCase {

    func testDetectsSubjectByCode() {
        let subjects = [makeSubject(id: "s1", name: "Artificial Neural Networks", code: "ANN")]
        let result = SubjectMatcher.extract(from: "ANN Assignment 2 due June 20", subjects: subjects)
        XCTAssertEqual(result.subjectId, "s1")
        XCTAssertEqual(result.subjectCode, "ANN")
    }

    func testDetectsSubjectByName() {
        let subjects = [makeSubject(id: "s2", name: "Machine Learning", code: "ML")]
        let result = SubjectMatcher.extract(from: "Machine Learning exam next Friday", subjects: subjects)
        XCTAssertEqual(result.subjectId, "s2")
    }

    func testDetectsAssignmentType() {
        let result = SubjectMatcher.extract(from: "ANN Assignment 2", subjects: [])
        XCTAssertEqual(result.type, .assignment)
    }

    func testDetectsExamType() {
        let result = SubjectMatcher.extract(from: "ML Quiz 3", subjects: [])
        XCTAssertEqual(result.type, .exam)
    }

    func testDetectsLabType() {
        let result = SubjectMatcher.extract(from: "CN Lab 4", subjects: [])
        XCTAssertEqual(result.type, .lab)
    }

    func testConfidenceHighWhenBothFound() {
        let subjects = [makeSubject(id: "s1", name: "ANN", code: "ANN")]
        let result = SubjectMatcher.extract(from: "ANN Assignment 2", subjects: subjects)
        XCTAssertEqual(result.confidence, .high)
    }

    func testConfidenceLowWhenNothingFound() {
        let result = SubjectMatcher.extract(from: "random text here", subjects: [])
        XCTAssertEqual(result.confidence, .low)
        XCTAssertTrue(result.unmatchedFields.contains("subject"))
        XCTAssertTrue(result.unmatchedFields.contains("type"))
    }

    func testConfidenceMediumWhenOnlyTypeFound() {
        let result = SubjectMatcher.extract(from: "Assignment 2", subjects: [])
        XCTAssertEqual(result.confidence, .medium)
    }

    func testParsesISODate() {
        let result = DateParser.extractDate(from: "Due 2025-06-20")
        XCTAssertEqual(result, "2025-06-20")
    }

    func testParsesMonthDayFormat() {
        let result = DateParser.extractDate(from: "due June 20")
        XCTAssertNotNil(result)
        XCTAssertTrue(result?.contains("-06-20") == true)
    }

    func testParsesTomorrow() {
        let result = DateParser.extractDate(from: "submit tomorrow")
        XCTAssertNotNil(result)
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        let expected = DateParser.iso8601Date(from: tomorrow)
        XCTAssertEqual(result, expected)
    }

    func testReturnsNilForNoDate() {
        let result = DateParser.extractDate(from: "ANN Assignment 2")
        XCTAssertNil(result)
    }

    private func makeSubject(id: String, name: String, code: String) -> Subject {
        Subject(id: id, semesterId: "sem1", name: name, code: code, color: nil,
                archived: false, sortOrder: 0,
                createdAt: "2025-01-01T00:00:00Z", updatedAt: "2025-01-01T00:00:00Z")
    }
}
