import Foundation
import GRDB

final class ALMSDatabase {
    let writer: DatabaseWriter
    
    @available(*, deprecated, message: "Use writer instead")
    var dbQueue: DatabaseWriter { writer }

    var isInMemory: Bool {
        writer is DatabaseQueue
    }

    static let shared: ALMSDatabase = {
        let appSupport = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ALMS")
        let dbURL = appSupport.appendingPathComponent("alms.db")
        do {
            return try ALMSDatabase(url: dbURL)
        } catch {
            fatalError("ALMS: Failed to open database at \(dbURL.path): \(error)")
        }
    }()

    init(url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true,
            attributes: nil
        )
        
        var config = Configuration()
        config.prepareDatabase { db in
            try db.execute(sql: "PRAGMA foreign_keys = ON")
        }
        
        writer = try DatabasePool(path: url.path, configuration: config)
        try setup()
    }

    init(inMemory: Bool) throws {
        precondition(inMemory, "Use init(url:) for persistent databases")
        
        var config = Configuration()
        config.prepareDatabase { db in
            try db.execute(sql: "PRAGMA foreign_keys = ON")
        }
        
        writer = try DatabaseQueue(configuration: config)
        try setup()
    }

    private func setup() throws {
        try runMigrations()
        try DefaultSeedData(db: self).seedIfNeeded()
    }

    private func runMigrations() throws {
        var migrator = DatabaseMigrator()
        V1InitialSchema.register(in: &migrator)
        try migrator.migrate(writer)
    }
}
