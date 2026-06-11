import Foundation

struct MetadataEngine {
    private let db: ALMSDatabase

    init(db: ALMSDatabase) { self.db = db }

    func extractFromText(_ text: String) throws -> ExtractedMetadata {
        let subjects = try activeSubjects()
        return SubjectMatcher.extract(from: text, subjects: subjects)
    }

    func extractFromTextAsync(_ text: String) async throws -> ExtractedMetadata {
        let subjects = try activeSubjects()
        #if canImport(FoundationModels)
        if #available(macOS 26, *), AIMetadataEngine.isAvailable {
            if let result = try? await AIMetadataEngine().extract(from: text, subjects: subjects) {
                return result
            }
        }
        #endif
        return SubjectMatcher.extract(from: text, subjects: subjects)
    }

    func extractFromFilename(_ filename: String) throws -> ExtractedMetadata {
        let subjects = try activeSubjects()
        return SubjectMatcher.extract(from: normalizedFilename(filename), subjects: subjects)
    }

    func extractFromFilenameAsync(_ filename: String) async throws -> ExtractedMetadata {
        let normalized = normalizedFilename(filename)
        let subjects = try activeSubjects()
        #if canImport(FoundationModels)
        if #available(macOS 26, *), AIMetadataEngine.isAvailable {
            if let result = try? await AIMetadataEngine().extract(from: normalized, subjects: subjects) {
                return result
            }
        }
        #endif
        return SubjectMatcher.extract(from: normalized, subjects: subjects)
    }

    private func normalizedFilename(_ filename: String) -> String {
        let base = URL(fileURLWithPath: filename).deletingPathExtension().lastPathComponent
        return base.replacingOccurrences(of: "[_\\-]", with: " ", options: .regularExpression)
    }

    private func activeSubjects() throws -> [Subject] {
        let semesterRepo = SemesterRepository(db: db)
        let subjectRepo = SubjectRepository(db: db)
        guard let semester = try semesterRepo.fetchActive() else { return [] }
        return try subjectRepo.fetchAll(semesterId: semester.id, includeArchived: false)
    }
}
