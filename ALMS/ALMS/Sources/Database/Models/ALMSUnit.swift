import Foundation
import GRDB

struct ALMSUnit: Codable, FetchableRecord, MutablePersistableRecord {
    static let databaseTableName = "units"

    var id: String
    var subjectId: String
    var name: String
    var number: Int
    var createdAt: String
    var updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id, name, number
        case subjectId = "subject_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
