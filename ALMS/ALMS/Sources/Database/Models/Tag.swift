import Foundation
import GRDB

struct Tag: Codable, FetchableRecord, MutablePersistableRecord {
    static let databaseTableName = "tags"

    var id: String
    var name: String
    var createdAt: String

    enum CodingKeys: String, CodingKey {
        case id, name
        case createdAt = "created_at"
    }
}
