#if canImport(FoundationModels)
import FoundationModels
import Foundation

@available(macOS 26, *)
@Generable
struct AIItemMetadata {
    @Guide(description: "Subject code exactly as listed in known subjects (e.g. ANN, ML, FLA). Empty string if not clearly mentioned.")
    var subjectCode: String

    @Guide(description: "Item type — must be exactly one of: assignment, exam, lab, project, notes, resource, event, pyq, other")
    var type: String

    @Guide(description: "Clean title: the item name only, without subject code, due dates, or connector words like 'due' / 'by'")
    var title: String

    @Guide(description: "Due date as yyyy-MM-dd. Resolve relative dates (tomorrow, next friday, 'due 29') using today's date. Empty string if no date mentioned.")
    var dueDate: String
}

@available(macOS 26, *)
struct AIMetadataEngine {

    static var isAvailable: Bool {
        if case .available = SystemLanguageModel.default.availability { return true }
        return false
    }

    func extract(from text: String, subjects: [Subject]) async throws -> ExtractedMetadata {
        let today = DateParser.iso8601Date(from: Date())
        let subjectList = subjects.map { s in
            s.code.map { "\($0) (\(s.name))" } ?? s.name
        }.joined(separator: ", ")

        let session = LanguageModelSession(instructions: """
            You extract structured metadata for ALMS, an academic task manager.
            Today: \(today).
            Known subjects this semester: \(subjectList.isEmpty ? "none" : subjectList)
            Match subject codes case-insensitively and return the exact code as listed.
            If the subject is not in the list, return empty string for subjectCode.
            """)

        let response = try await session.respond(to: text, generating: AIItemMetadata.self)
        let ai = response.content

        // Resolve code → Subject
        let matched = subjects.first { s in
            guard let code = s.code, !ai.subjectCode.isEmpty else { return false }
            return code.lowercased() == ai.subjectCode.lowercased()
        } ?? subjects.first { s in
            guard !ai.subjectCode.isEmpty else { return false }
            return s.name.lowercased() == ai.subjectCode.lowercased()
        }

        let itemType = ItemType(rawValue: ai.type.lowercased()) ?? .other
        let dueDateValue = ai.dueDate.isEmpty ? nil : ai.dueDate
        let unmatched = matched == nil ? ["subject"] : []
        let confidence: ExtractedMetadata.Confidence = unmatched.isEmpty ? .high : .medium

        return ExtractedMetadata(
            subjectId: matched?.id,
            subjectCode: matched?.code,
            unitId: nil,
            type: itemType,
            title: ai.title.isEmpty ? text : ai.title,
            dueDate: dueDateValue,
            confidence: confidence,
            unmatchedFields: unmatched
        )
    }
}
#endif
