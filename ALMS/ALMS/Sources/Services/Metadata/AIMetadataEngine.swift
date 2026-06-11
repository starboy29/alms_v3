import Foundation

struct FileInterpretation: Equatable {
    var subjectCode: String
    var subjectName: String
    var unitName: String
    var folderName: String
    var title: String
    var isUnsure: Bool = false
}

#if canImport(FoundationModels)
import FoundationModels

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
@Generable
struct AIFileMetadata {
    @Guide(description: "Subject code (e.g. ANN, ML). Match from known subjects if possible; suggest a short uppercase code if new. Empty string only if file has no academic subject at all.")
    var subjectCode: String

    @Guide(description: "Full subject name. Match existing subject if possible. Infer from description if new (e.g. 'Artificial Neural Networks', 'Data Structures').")
    var subjectName: String

    @Guide(description: "Unit or chapter name (e.g. 'Unit 3', 'Chapter 2 - Backpropagation'). Empty string if file doesn't belong to a specific unit.")
    var unitName: String

    @Guide(description: "Folder category for this file. Use free-form naming that fits the description (e.g. 'Notes', 'Important Topics', 'Past Papers', 'Lab Reports'). Default to 'Notes' if unclear.")
    var folderName: String

    @Guide(description: "Clean descriptive title for this file, without subject code or unit prefix.")
    var title: String

    @Guide(description: "true if uncertain about subject identification or classification — e.g. description is vague, subject not in the known list, or multiple interpretations are possible. false if confident.")
    var isUnsure: Bool
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

    func extractFromFileDescription(
        filename: String,
        description: String,
        subjects: [Subject]
    ) async throws -> FileInterpretation {
        let subjectList = subjects.map { s in
            s.code.map { "\($0) (\(s.name))" } ?? s.name
        }.joined(separator: ", ")

        let session = LanguageModelSession(instructions: """
            You interpret user descriptions of academic files to extract structured metadata for ALMS.
            Known subjects this semester: \(subjectList.isEmpty ? "none — the user may be adding a new subject" : subjectList)
            If the subject matches a known one, use its exact code and name.
            If it's a new subject, infer a short uppercase code and full name from context.
            Set isUnsure to true when the description is vague or the subject cannot be confidently identified.
            """)

        let prompt = "File: \(filename)\nUser description: \(description)"
        let response = try await session.respond(to: prompt, generating: AIFileMetadata.self)
        let ai = response.content

        return FileInterpretation(
            subjectCode: ai.subjectCode,
            subjectName: ai.subjectName,
            unitName: ai.unitName,
            folderName: ai.folderName.isEmpty ? "Notes" : ai.folderName,
            title: ai.title,
            isUnsure: ai.isUnsure
        )
    }
}
#endif
