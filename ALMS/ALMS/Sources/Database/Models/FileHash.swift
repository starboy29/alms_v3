import Foundation
import GRDB

struct FileHash: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "file_hashes"

    var sha256: String
    var fileId: String
    var detectedAt: String

    enum CodingKeys: String, CodingKey {
        case sha256
        case fileId = "file_id"
        case detectedAt = "detected_at"
    }
}
