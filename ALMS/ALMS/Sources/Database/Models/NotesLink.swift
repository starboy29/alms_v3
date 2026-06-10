import Foundation
import GRDB

struct NotesLink: Codable, FetchableRecord, MutablePersistableRecord {
    static let databaseTableName = "notes_links"

    var id: String
    var itemId: String
    var noteExtId: String?
    var noteTitle: String
    var folderName: String
    var account: String
    var status: String
    var lastSyncedAt: String?
    var errorMessage: String?
    var retryCount: Int
    var createdAt: String
    var updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id, status, account
        case itemId = "item_id"
        case noteExtId = "note_ext_id"
        case noteTitle = "note_title"
        case folderName = "folder_name"
        case lastSyncedAt = "last_synced_at"
        case errorMessage = "error_message"
        case retryCount = "retry_count"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
