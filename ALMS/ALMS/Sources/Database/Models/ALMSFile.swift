import Foundation
import GRDB

struct ALMSFile: Codable, FetchableRecord, MutablePersistableRecord {
    static let databaseTableName = "files"

    var id: String
    var itemId: String?
    var originalName: String
    var storedName: String?
    var storedPath: String
    var fileHash: String
    var fileSize: Int
    var mimeType: String?
    var finderVerified: Bool
    var createdAt: String
    var updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case itemId = "item_id"
        case originalName = "original_name"
        case storedName = "stored_name"
        case storedPath = "stored_path"
        case fileHash = "file_hash"
        case fileSize = "file_size"
        case mimeType = "mime_type"
        case finderVerified = "finder_verified"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
