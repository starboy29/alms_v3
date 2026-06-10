import Foundation
import GRDB

struct AppSetting: Codable, FetchableRecord, MutablePersistableRecord {
    static let databaseTableName = "settings"

    var key: String
    var value: String
    var updatedAt: String

    enum CodingKeys: String, CodingKey {
        case key, value
        case updatedAt = "updated_at"
    }
}
