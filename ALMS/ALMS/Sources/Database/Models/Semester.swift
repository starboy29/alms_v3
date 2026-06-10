import Foundation
import GRDB

struct Semester: Codable, FetchableRecord, MutablePersistableRecord {
    static let databaseTableName = "semesters"

    var id: String
    var name: String
    var startDate: String?
    var endDate: String?
    var isActive: Bool
    var createdAt: String
    var updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id, name
        case startDate = "start_date"
        case endDate = "end_date"
        case isActive = "is_active"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
