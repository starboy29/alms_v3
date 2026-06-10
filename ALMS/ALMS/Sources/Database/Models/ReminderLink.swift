import Foundation
import GRDB

struct ReminderLink: Codable, FetchableRecord, MutablePersistableRecord {
    static let databaseTableName = "reminder_links"

    var id: String
    var itemId: String
    var reminderExtId: String?
    var reminderTitle: String
    var listName: String
    var status: String
    var lastSyncedAt: String?
    var errorMessage: String?
    var retryCount: Int
    var createdAt: String
    var updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id, status
        case itemId = "item_id"
        case reminderExtId = "reminder_ext_id"
        case reminderTitle = "reminder_title"
        case listName = "list_name"
        case lastSyncedAt = "last_synced_at"
        case errorMessage = "error_message"
        case retryCount = "retry_count"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
