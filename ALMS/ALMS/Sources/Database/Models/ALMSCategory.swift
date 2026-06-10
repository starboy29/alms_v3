import Foundation
import GRDB

struct ALMSCategory: Codable, FetchableRecord, MutablePersistableRecord {
    static let databaseTableName = "categories"

    var id: String
    var unitId: String
    var name: String
    var type: String
    var sortOrder: Int
    var createdAt: String
    var updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id, name, type
        case unitId = "unit_id"
        case sortOrder = "sort_order"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

enum CategoryType: String {
    case notes, assignment, lab, pyq, resource, custom
}
