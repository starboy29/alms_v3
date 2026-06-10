import Foundation

struct MetadataEngine {
    private let db: ALMSDatabase

    init(db: ALMSDatabase) { self.db = db }

    func extractFromText(_ text: String) throws -> ExtractedMetadata {
        let subjects = try activeSubjects()
        return SubjectMatcher.extract(from: text, subjects: subjects)
    }

    func extractFromFilename(_ filename: String) throws -> ExtractedMetadata {
        let base = URL(fileURLWithPath: filename).deletingPathExtension().lastPathComponent
        let normalized = base.replacingOccurrences(of: "[_\\-]", with: " ", options: .regularExpression)
        let subjects = try activeSubjects()
        return SubjectMatcher.extract(from: normalized, subjects: subjects)
    }

    private func activeSubjects() throws -> [Subject] {
        let semesterRepo = SemesterRepository(db: db)
        let subjectRepo = SubjectRepository(db: db)
        guard let semester = try semesterRepo.fetchActive() else { return [] }
        return try subjectRepo.fetchAll(semesterId: semester.id, includeArchived: false)
    }
}
