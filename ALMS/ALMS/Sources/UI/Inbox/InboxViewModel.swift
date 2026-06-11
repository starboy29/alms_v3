import AppKit
import Foundation
import UniformTypeIdentifiers

struct InboxRow: Identifiable {
    var id: String { item.id }
    let item: Item
    let subjectCode: String?
    let unitName: String?
}

@Observable
final class InboxViewModel {
    var inputText = ""
    var isProcessing = false
    var pendingMetadata: ExtractedMetadata?
    var pendingFilePath: String?
    var showConfirmation = false
    var showFileDescription = false
    var pendingFileDescriptionPath: String?
    var pendingReviewInterpretation: FileInterpretation?
    var errorMessage: String?
    var showError = false
    var isDragTargeted = false
    var recentItems: [InboxRow] = []
    var showClearConfirm = false

    let db: ALMSDatabase

    init(db: ALMSDatabase) {
        self.db = db
        loadRecentItems()
    }

    private var service: InboxService { InboxService(db: db) }

    func submit() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        isProcessing = true
        Task { @MainActor in
            defer { isProcessing = false }
            do {
                let result = try await service.submitText(text)
                if result.needsConfirmation {
                    pendingMetadata = result.metadata
                    showConfirmation = true
                } else {
                    inputText = ""
                    loadRecentItems()
                }
            } catch {
                showErrorMessage(error.localizedDescription)
            }
        }
    }

    func handleDroppedFile(at path: String) {
        isProcessing = true
        Task { @MainActor in
            defer { isProcessing = false }
            do {
                try service.validateFile(path)
                pendingFileDescriptionPath = path
                showFileDescription = true
            } catch InboxError.duplicateFile(_) {
                showErrorMessage("This file has already been imported.")
            } catch {
                showErrorMessage(error.localizedDescription)
            }
        }
    }

    func submitFileWithDescription(_ description: String) {
        guard let path = pendingFileDescriptionPath else { return }
        isProcessing = true
        Task { @MainActor in
            defer { isProcessing = false }
            do {
                let interp = try await getFileInterpretation(path: path, description: description)
                if interp.isUnsure {
                    pendingReviewInterpretation = interp
                } else {
                    try await fileWithInterpretation(path: path, interp: interp)
                }
            } catch {
                showErrorMessage(error.localizedDescription)
            }
        }
    }

    func confirmReviewAndFile(_ interp: FileInterpretation) {
        guard let path = pendingFileDescriptionPath else { return }
        isProcessing = true
        Task { @MainActor in
            defer { isProcessing = false }
            do {
                try await fileWithInterpretation(path: path, interp: interp)
            } catch {
                showErrorMessage(error.localizedDescription)
            }
        }
    }

    func clearReview() {
        pendingReviewInterpretation = nil
    }

    func cancelFileDescription() {
        showFileDescription = false
        pendingFileDescriptionPath = nil
        pendingReviewInterpretation = nil
    }

    func confirmMetadata(_ confirmed: ConfirmedMetadata) {
        isProcessing = true
        Task { @MainActor in
            defer { isProcessing = false }
            do {
                if let path = pendingFilePath {
                    _ = try await service.submitFile(path, confirmedMetadata: confirmed)
                } else {
                    _ = try service.submitConfirmedText(confirmed)
                }
                reset()
                loadRecentItems()
            } catch {
                showErrorMessage(error.localizedDescription)
            }
        }
    }

    func dismissConfirmation() {
        reset()
    }

    func openFilePicker() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.pdf, .presentation, .spreadsheet, .text,
                                     .image, .zip, .data]
        panel.title = "Choose a file to import"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        handleDroppedFile(at: url.path)
    }

    func clearAll() {
        do {
            try ItemRepository(db: db).archiveAll()
            SpotlightService().deindexAll()
            loadRecentItems()
        } catch {
            showErrorMessage(error.localizedDescription)
        }
    }

    func loadRecentItems() {
        let all = (try? ItemRepository(db: db).fetchAll()) ?? []
        let items = Array(all.prefix(40))

        let subjectRepo = SubjectRepository(db: db)
        let unitRepo = UnitRepository(db: db)

        var subjectMap: [String: String] = [:]
        for id in Set(items.map(\.subjectId)) {
            if let s = try? subjectRepo.fetchById(id) {
                subjectMap[id] = s.code?.isEmpty == false ? s.code! : s.name
            }
        }
        var unitMap: [String: String] = [:]
        for id in Set(items.compactMap(\.unitId)) {
            if let u = try? unitRepo.fetchById(id) {
                unitMap[id] = u.name
            }
        }

        recentItems = items.map { item in
            InboxRow(
                item: item,
                subjectCode: subjectMap[item.subjectId],
                unitName: item.unitId.flatMap { unitMap[$0] }
            )
        }
    }

    // MARK: - Private

    private func fileWithInterpretation(path: String, interp: FileInterpretation) async throws {
        let subjectId = try findOrCreateSubject(code: interp.subjectCode, name: interp.subjectName)
        let unitId: String? = interp.unitName.isEmpty
            ? nil
            : (try? findOrCreateUnit(name: interp.unitName, subjectId: subjectId))
        let filename = URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent
        let confirmed = ConfirmedMetadata(
            subjectId: subjectId,
            unitId: unitId,
            categoryId: nil,
            type: .notes,
            title: interp.title.isEmpty ? filename : interp.title,
            dueDate: nil,
            priority: .medium,
            customFolderName: interp.folderName.isEmpty ? nil : interp.folderName
        )
        _ = try await service.submitFile(path, confirmedMetadata: confirmed)
        showFileDescription = false
        pendingFileDescriptionPath = nil
        pendingReviewInterpretation = nil
        loadRecentItems()
    }

    private func getFileInterpretation(path: String, description: String) async throws -> FileInterpretation {
        let filename = URL(fileURLWithPath: path).lastPathComponent
        let semesterRepo = SemesterRepository(db: db)
        let subjectRepo = SubjectRepository(db: db)
        var subjects: [Subject] = []
        if let semester = try? semesterRepo.fetchActive() {
            subjects = (try? subjectRepo.fetchAll(semesterId: semester.id, includeArchived: false)) ?? []
        }

        #if canImport(FoundationModels)
        if #available(macOS 26, *), AIMetadataEngine.isAvailable {
            if let result = try? await AIMetadataEngine().extractFromFileDescription(
                filename: filename, description: description, subjects: subjects
            ) {
                return result
            }
        }
        #endif

        // Fallback: regex extraction — always mark unsure so the user confirms
        let extracted = try await MetadataEngine(db: db).extractFromTextAsync(description)
        let matched = subjects.first { $0.id == extracted.subjectId }
        return FileInterpretation(
            subjectCode: matched?.code ?? extracted.subjectCode ?? "",
            subjectName: matched?.name ?? "",
            unitName: "",
            folderName: "Notes",
            title: extracted.title ?? filename,
            isUnsure: true
        )
    }

    private func findOrCreateSubject(code: String, name: String) throws -> String {
        let semesterRepo = SemesterRepository(db: db)
        guard let semester = try semesterRepo.fetchActive() else {
            throw InboxError.metadataRequired
        }
        let subjectRepo = SubjectRepository(db: db)
        let trimmedCode = code.trimmingCharacters(in: .whitespaces)
        let trimmedName = name.trimmingCharacters(in: .whitespaces)

        if !trimmedCode.isEmpty,
           let existing = try subjectRepo.fetchByCode(trimmedCode, semesterId: semester.id) {
            return existing.id
        }

        let all = try subjectRepo.fetchAll(semesterId: semester.id, includeArchived: false)
        if !trimmedName.isEmpty,
           let existing = all.first(where: { $0.name.lowercased() == trimmedName.lowercased() }) {
            return existing.id
        }

        guard !trimmedName.isEmpty || !trimmedCode.isEmpty else {
            throw InboxError.metadataRequired
        }

        let now = ISO8601DateFormatter().string(from: Date())
        let subject = Subject(
            id: UUID().uuidString,
            semesterId: semester.id,
            name: trimmedName.isEmpty ? trimmedCode : trimmedName,
            code: trimmedCode.isEmpty ? nil : trimmedCode,
            color: nil,
            archived: false,
            sortOrder: all.count,
            createdAt: now,
            updatedAt: now
        )
        try subjectRepo.insert(subject)
        return subject.id
    }

    private func findOrCreateUnit(name: String, subjectId: String) throws -> String {
        let unitRepo = UnitRepository(db: db)
        let existing = try unitRepo.fetchAll(subjectId: subjectId)
        let trimmed = name.trimmingCharacters(in: .whitespaces)

        if let found = existing.first(where: { $0.name.lowercased() == trimmed.lowercased() }) {
            return found.id
        }

        let now = ISO8601DateFormatter().string(from: Date())
        let unit = ALMSUnit(
            id: UUID().uuidString,
            subjectId: subjectId,
            name: trimmed,
            number: existing.count + 1,
            createdAt: now,
            updatedAt: now
        )
        try unitRepo.insert(unit)
        return unit.id
    }

    private func reset() {
        showConfirmation = false
        pendingMetadata = nil
        pendingFilePath = nil
        inputText = ""
    }

    private func showErrorMessage(_ msg: String) {
        errorMessage = msg
        showError = true
    }
}