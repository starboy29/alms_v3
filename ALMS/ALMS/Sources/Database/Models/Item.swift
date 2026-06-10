import Foundation
import GRDB

struct Item: Codable, FetchableRecord, MutablePersistableRecord {
    static let databaseTableName = "items"

    var id: String
    var subjectId: String
    var unitId: String?
    var categoryId: String?
    var type: String
    var title: String
    var description: String?
    var dueDate: String?
    var dueTime: String?
    var priority: String
    var source: String?
    var status: String
    var createdAt: String
    var updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id, type, title, description, priority, source, status
        case subjectId = "subject_id"
        case unitId = "unit_id"
        case categoryId = "category_id"
        case dueDate = "due_date"
        case dueTime = "due_time"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

enum ItemType: String {
    case notes, assignment, exam, lab, project, resource, event, other

    /// Folder name used when filing a file of this type, e.g. a notes PDF lands in a "Notes" folder.
    var folderName: String {
        switch self {
        case .notes:      return "Notes"
        case .assignment: return "Assignments"
        case .exam:       return "Exams"
        case .lab:        return "Labs"
        case .project:    return "Projects"
        case .resource:   return "Resources"
        case .event:      return "Events"
        case .other:      return "Other"
        }
    }
}

enum ItemPriority: String {
    case low, medium, high
}

enum ItemStatus: String {
    case active, completed, archived
}
