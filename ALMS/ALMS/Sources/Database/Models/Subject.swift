import Foundation
import GRDB

struct Subject: Codable, FetchableRecord, MutablePersistableRecord {
    static let databaseTableName = "subjects"

    var id: String
    var semesterId: String
    var name: String
    var code: String?
    var color: String?
    var archived: Bool
    var sortOrder: Int
    var createdAt: String
    var updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id, name, code, color, archived
        case semesterId = "semester_id"
        case sortOrder = "sort_order"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
