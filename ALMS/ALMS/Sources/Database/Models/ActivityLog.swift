import Foundation
import GRDB

struct ActivityLog: Codable, FetchableRecord, MutablePersistableRecord {
    static let databaseTableName = "activity_logs"

    var id: String
    var eventType: String
    var entityType: String?
    var entityId: String?
    var details: String
    var errorMessage: String?
    var metadata: String?
    var createdAt: String

    enum CodingKeys: String, CodingKey {
        case id, metadata
        case details = "description"
        case errorMessage = "error"
        case eventType = "event_type"
        case entityType = "entity_type"
        case entityId = "entity_id"
        case createdAt = "created_at"
    }
}

enum LogEventType: String {
    case `import`, sync, update
    case runtimeError = "error"
    case duplicatePrevented = "duplicate_prevented"
    case shortcutCall = "shortcut_call"
    case fileMove = "file_move"
    case retry
    case settingsChange = "settings_change"
}
