import Foundation
import GRDB

struct CalendarLink: Codable, FetchableRecord, MutablePersistableRecord {
    static let databaseTableName = "calendar_links"

    var id: String
    var itemId: String
    var eventExtId: String?
    var eventTitle: String
    var calendarName: String
    var eventDate: String
    var allDay: Bool
    var status: String
    var lastSyncedAt: String?
    var errorMessage: String?
    var retryCount: Int
    var createdAt: String
    var updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id, status
        case itemId = "item_id"
        case eventExtId = "event_ext_id"
        case eventTitle = "event_title"
        case calendarName = "calendar_name"
        case eventDate = "event_date"
        case allDay = "all_day"
        case lastSyncedAt = "last_synced_at"
        case errorMessage = "error_message"
        case retryCount = "retry_count"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
