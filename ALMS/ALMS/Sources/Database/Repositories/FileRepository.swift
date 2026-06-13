import Foundation
import GRDB

struct FileRepository {
    private let db: ALMSDatabase

    init(db: ALMSDatabase) { self.db = db }

    func insert(file: ALMSFile, hash: FileHash) throws {
        var f = file
        try db.dbQueue.write { db in
            try f.insert(db)
            try hash.insert(db)
        }
    }

    func fetchByItemId(_ itemId: String) throws -> ALMSFile? {
        try db.dbQueue.read { db in
            try ALMSFile.filter(Column("item_id") == itemId).fetchOne(db)
        }
    }

    func fetchPathMap(itemIds: [String]) throws -> [String: String] {
        guard !itemIds.isEmpty else { return [:] }
        return try db.dbQueue.read { db in
            let files = try ALMSFile
                .filter(itemIds.contains(Column("item_id")))
                .fetchAll(db)
            return Dictionary(uniqueKeysWithValues: files.compactMap { f in
                guard let itemId = f.itemId else { return nil }
                return (itemId, f.storedPath)
            })
        }
    }

    func fetchById(_ id: String) throws -> ALMSFile? {
        try db.dbQueue.read { db in try ALMSFile.fetchOne(db, key: id) }
    }

    func findByHash(_ sha256: String) throws -> ALMSFile? {
        try db.dbQueue.read { db in
            try ALMSFile.filter(Column("file_hash") == sha256).fetchOne(db)
        }
    }

    func isDuplicate(sha256: String) throws -> Bool {
        try db.dbQueue.read { db in
            try FileHash.fetchOne(db, key: sha256) != nil
        }
    }

    func updateStoredPath(id: String, storedPath: String, storedName: String?) throws {
        try db.dbQueue.write { db in
            try db.execute(
                sql: """
                    UPDATE files SET stored_path = ?, stored_name = ?,
                    updated_at = ? WHERE id = ?
                """,
                arguments: [storedPath, storedName, now(), id]
            )
        }
    }

    func markUnverified(id: String) throws {
        try db.dbQueue.write { db in
            try db.execute(
                sql: "UPDATE files SET finder_verified = 0, updated_at = ? WHERE id = ?",
                arguments: [now(), id]
            )
        }
    }

    func fetchUnverified() throws -> [ALMSFile] {
        try db.dbQueue.read { db in
            try ALMSFile.filter(Column("finder_verified") == false).fetchAll(db)
        }
    }

    private func now() -> String { ISO8601DateFormatter().string(from: Date()) }
}
