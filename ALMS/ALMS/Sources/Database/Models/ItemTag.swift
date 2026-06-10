import Foundation
import GRDB

struct ItemTag: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "item_tags"

    var itemId: String
    var tagId: String

    enum CodingKeys: String, CodingKey {
        case itemId = "item_id"
        case tagId = "tag_id"
    }
}
