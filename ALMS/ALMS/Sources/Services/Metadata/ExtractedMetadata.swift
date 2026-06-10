import Foundation

struct ExtractedMetadata {
    enum Confidence: String { case high, medium, low }

    var subjectId: String?
    var subjectCode: String?
    var unitId: String?
    var type: ItemType?
    var title: String?
    var dueDate: String?
    var confidence: Confidence
    var unmatchedFields: [String]
}
