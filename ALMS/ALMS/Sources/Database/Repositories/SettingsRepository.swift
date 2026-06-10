import Foundation
import GRDB

struct SettingsRepository {
    private let db: ALMSDatabase

    init(db: ALMSDatabase) { self.db = db }

    func set<T: Encodable>(key: String, value: T) throws {
        let encoded = try JSONEncoder().encode(value)
        let jsonString = String(data: encoded, encoding: .utf8)!
        var setting = AppSetting(
            key: key,
            value: jsonString,
            updatedAt: ISO8601DateFormatter().string(from: Date())
        )
        try db.dbQueue.write { db in try setting.save(db) }
    }

    func getString(key: String, default defaultValue: String? = nil) throws -> String? {
        guard let raw = try getRaw(key: key) else { return defaultValue }
        return try JSONDecoder().decode(String.self, from: raw)
    }

    func getBool(key: String, default defaultValue: Bool = false) throws -> Bool {
        guard let raw = try getRaw(key: key) else { return defaultValue }
        return try JSONDecoder().decode(Bool.self, from: raw)
    }

    func getInt(key: String, default defaultValue: Int = 0) throws -> Int {
        guard let raw = try getRaw(key: key) else { return defaultValue }
        return try JSONDecoder().decode(Int.self, from: raw)
    }

    func getAll() throws -> [String: String] {
        let settings = try db.dbQueue.read { db in try AppSetting.fetchAll(db) }
        return Dictionary(uniqueKeysWithValues: settings.map { ($0.key, $0.value) })
    }

    private func getRaw(key: String) throws -> Data? {
        let setting = try db.dbQueue.read { db in try AppSetting.fetchOne(db, key: key) }
        return setting.flatMap { $0.value.data(using: .utf8) }
    }
}
