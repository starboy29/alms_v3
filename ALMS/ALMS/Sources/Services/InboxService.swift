import Foundation
import CryptoKit
import UniformTypeIdentifiers

struct InboxResult {
    let itemId: String
    let needsConfirmation: Bool
    let metadata: ExtractedMetadata
}

struct ConfirmedMetadata {
    let subjectId: String
    let unitId: String?
    let categoryId: String?
    let type: ItemType
    let title: String
    let dueDate: String?
    let priority: ItemPriority
    let customFolderName: String?

    init(subjectId: String, unitId: String?, categoryId: String?,
         type: ItemType, title: String, dueDate: String?,
         priority: ItemPriority, customFolderName: String? = nil) {
        self.subjectId = subjectId; self.unitId = unitId; self.categoryId = categoryId
        self.type = type; self.title = title; self.dueDate = dueDate
        self.priority = priority; self.customFolderName = customFolderName
    }
}

enum InboxError: LocalizedError {
    case duplicateFile(existingFileId: String?)
    case metadataRequired
    case fileNotFound(path: String)

    var errorDescription: String? {
        switch self {
        case .duplicateFile(let id):
            return "Duplicate file (existing ID: \(id ?? "unknown"))"
        case .metadataRequired:
            return "Subject and type are required to submit this item"
        case .fileNotFound(let p):
            return "File not found at path: \(p)"
        }
    }
}

struct InboxService {
    private let db: ALMSDatabase

    init(db: ALMSDatabase) {
        self.db = db
    }

    func validateFile(_ filePath: String) throws {
        guard FileManager.default.fileExists(atPath: filePath) else {
            throw InboxError.fileNotFound(path: filePath)
        }
        let sha256 = try computeSHA256(at: filePath)
        let dupeCheck = try DuplicateGuard(db: db).checkFile(sha256: sha256)
        if dupeCheck.isDuplicate {
            throw InboxError.duplicateFile(existingFileId: dupeCheck.existingFileId)
        }
    }

    func submitText(_ text: String) async throws -> InboxResult {
        let engine = MetadataEngine(db: db)
        let metadata = try await engine.extractFromTextAsync(text)

        guard metadata.confidence != .low,
              let subjectId = metadata.subjectId,
              let type = metadata.type else {
            return InboxResult(itemId: "", needsConfirmation: true, metadata: metadata)
        }

        let item = try createItem(
            subjectId: subjectId,
            unitId: metadata.unitId,
            type: type,
            title: metadata.title ?? text,
            dueDate: metadata.dueDate,
            priority: .medium,
            source: "inbox_text"
        )

        try routeItem(item)
        SpotlightService().index(item, db: db)
        return InboxResult(itemId: item.id, needsConfirmation: false, metadata: metadata)
    }

    func submitConfirmedText(_ confirmed: ConfirmedMetadata) throws -> InboxResult {
        let item = try createItem(
            subjectId: confirmed.subjectId,
            unitId: confirmed.unitId,
            type: confirmed.type,
            title: confirmed.title,
            dueDate: confirmed.dueDate,
            priority: confirmed.priority,
            source: "inbox_text"
        )
        try routeItem(item)
        SpotlightService().index(item, db: db)
        let meta = ExtractedMetadata(
            subjectId: confirmed.subjectId, subjectCode: nil,
            unitId: confirmed.unitId, type: confirmed.type,
            title: confirmed.title, dueDate: confirmed.dueDate,
            confidence: .high, unmatchedFields: []
        )
        return InboxResult(itemId: item.id, needsConfirmation: false, metadata: meta)
    }

    func submitFile(_ filePath: String, confirmedMetadata: ConfirmedMetadata? = nil) async throws -> InboxResult {
        guard FileManager.default.fileExists(atPath: filePath) else {
            throw InboxError.fileNotFound(path: filePath)
        }

        let sha256 = try computeSHA256(at: filePath)
        let dupeCheck = try DuplicateGuard(db: db).checkFile(sha256: sha256)
        if dupeCheck.isDuplicate {
            throw InboxError.duplicateFile(existingFileId: dupeCheck.existingFileId)
        }

        let confirmed: ConfirmedMetadata
        if let cm = confirmedMetadata {
            confirmed = cm
        } else {
            let engine = MetadataEngine(db: db)
            let filename = URL(fileURLWithPath: filePath).lastPathComponent
            let metadata = try await engine.extractFromFilenameAsync(filename)

            guard metadata.confidence != .low,
                  let subjectId = metadata.subjectId,
                  let type = metadata.type else {
                return InboxResult(itemId: "", needsConfirmation: true, metadata: metadata)
            }
            confirmed = ConfirmedMetadata(
                subjectId: subjectId, unitId: metadata.unitId, categoryId: nil,
                type: type, title: metadata.title ?? filename,
                dueDate: metadata.dueDate, priority: .medium
            )
        }

        let subjectRepo = SubjectRepository(db: db)
        let subject = try subjectRepo.fetchById(confirmed.subjectId)

        // Build the full hierarchy: Root / Semester / Subject / Chapter(Unit) / Type.
        // (try? returns a double optional here — `?? nil` flattens it to a plain optional.)
        let semesterName = ((try? SemesterRepository(db: db).fetchActive()) ?? nil)?.name
        var unitName: String? = nil
        if let unitId = confirmed.unitId,
           let unit = (try? UnitRepository(db: db).fetchById(unitId)) ?? nil {
            unitName = unit.name
        }

        let subjectCode = subject?.code?.isEmpty == false ? subject!.code! : subject?.name ?? confirmed.subjectId
        let finder = FinderService(db: db)
        let destFolder = try finder.buildPath(
            semester: semesterName,
            subjectCode: subjectCode,
            unitName: unitName,
            categoryName: confirmed.customFolderName ?? confirmed.type.folderName
        )
        let originalFilename = URL(fileURLWithPath: filePath).lastPathComponent
        let ext = URL(fileURLWithPath: originalFilename).pathExtension
        let storedFilename = buildStoredName(subjectCode: subjectCode, title: confirmed.title, ext: ext)
        let destPath = uniqueDestPath(destFolder + "/" + storedFilename)

        let finalPath = try finder.moveFile(from: filePath, to: destPath)

        let item = try createItem(
            subjectId: confirmed.subjectId,
            unitId: confirmed.unitId,
            type: confirmed.type,
            title: confirmed.title,
            dueDate: confirmed.dueDate,
            priority: confirmed.priority,
            source: "inbox_file"
        )

        let now = ISO8601DateFormatter().string(from: Date())
        let attrs = try? FileManager.default.attributesOfItem(atPath: finalPath)
        let fileSize = attrs?[.size] as? Int ?? 0
        let mimeType = UTType(filenameExtension: ext.isEmpty ? "pdf" : ext)?.preferredMIMEType

        let actualStoredName = URL(fileURLWithPath: finalPath).lastPathComponent
        let fileRecord = ALMSFile(
            id: UUID().uuidString, itemId: item.id,
            originalName: originalFilename, storedName: actualStoredName,
            storedPath: finalPath, fileHash: sha256,
            fileSize: fileSize, mimeType: mimeType,
            finderVerified: true, createdAt: now, updatedAt: now
        )
        let hashRecord = FileHash(sha256: sha256, fileId: fileRecord.id, detectedAt: now)
        try FileRepository(db: db).insert(file: fileRecord, hash: hashRecord)

        let logger = ActivityLogRepository(db: db)
        logger.log(eventType: .fileMove, entityId: fileRecord.id,
                   details: "File moved to \(finalPath)")

        let folderLabel = URL(fileURLWithPath: finalPath).deletingLastPathComponent().lastPathComponent
        NotificationService.send(title: "File Filed", body: "\(actualStoredName) → \(folderLabel)")

        try routeItem(item)
        SpotlightService().index(item, db: db)

        let finalMetadata = ExtractedMetadata(
            subjectId: confirmed.subjectId, subjectCode: subject?.code,
            unitId: confirmed.unitId, type: confirmed.type,
            title: confirmed.title, dueDate: confirmed.dueDate,
            confidence: .high, unmatchedFields: []
        )
        return InboxResult(itemId: item.id, needsConfirmation: false, metadata: finalMetadata)
    }

    private func createItem(
        subjectId: String, unitId: String?,
        type: ItemType, title: String,
        dueDate: String?, priority: ItemPriority,
        source: String
    ) throws -> Item {
        let now = ISO8601DateFormatter().string(from: Date())
        let item = Item(
            id: UUID().uuidString, subjectId: subjectId,
            unitId: unitId, categoryId: nil,
            type: type.rawValue, title: title, description: nil,
            dueDate: dueDate, dueTime: nil,
            priority: priority.rawValue, source: source,
            status: ItemStatus.active.rawValue,
            createdAt: now, updatedAt: now
        )
        try ItemRepository(db: db).insert(item)
        ActivityLogRepository(db: db).log(
            eventType: .import, entityId: item.id,
            details: "Item created: \(title)"
        )
        return item
    }

    private func routeItem(_ item: Item) throws {
        let routing = RoutingEngine(db: db)
        let targets = routing.route(item: item)
        try routing.execute(itemId: item.id, targets: targets)
    }

    private func buildStoredName(subjectCode: String, title: String, ext: String) -> String {
        let base = "\(subjectCode) - \(title)"
        let invalid = CharacterSet(charactersIn: "/:\\*?\"<>|")
        let safe = String(base.unicodeScalars.map { invalid.contains($0) ? "-" : Character($0) })
        let trimmed = safe.trimmingCharacters(in: .whitespacesAndNewlines)
        return ext.isEmpty ? trimmed : "\(trimmed).\(ext)"
    }

    private func uniqueDestPath(_ desired: String) -> String {
        guard FileManager.default.fileExists(atPath: desired) else { return desired }
        let url = URL(fileURLWithPath: desired)
        let ext = url.pathExtension
        let base = url.deletingPathExtension().path
        var counter = 2
        while counter < 100 {
            let candidate = ext.isEmpty ? "\(base) (\(counter))" : "\(base) (\(counter)).\(ext)"
            if !FileManager.default.fileExists(atPath: candidate) { return candidate }
            counter += 1
        }
        return desired
    }

    private func computeSHA256(at path: String) throws -> String {
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
