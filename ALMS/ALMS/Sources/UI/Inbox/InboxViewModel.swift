import AppKit
import Foundation
import UniformTypeIdentifiers

struct InboxRow {
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

    private var service: InboxService { InboxService(db: db, bridge: ShortcutsBridge()) }

    func submit() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        isProcessing = true
        defer { isProcessing = false }
        do {
            let result = try service.submitText(text)
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

    func handleDroppedFile(at path: String) {
        isProcessing = true
        defer { isProcessing = false }
        do {
            let result = try service.submitFile(path)
            if result.needsConfirmation {
                pendingMetadata = result.metadata
                pendingFilePath = path
                showConfirmation = true
            } else {
                loadRecentItems()
            }
        } catch InboxError.duplicateFile(_) {
            showErrorMessage("This file has already been imported.")
        } catch {
            showErrorMessage(error.localizedDescription)
        }
    }

    func confirmMetadata(_ confirmed: ConfirmedMetadata) {
        isProcessing = true
        defer { isProcessing = false }
        do {
            if let path = pendingFilePath {
                _ = try service.submitFile(path, confirmedMetadata: confirmed)
            } else {
                let now = ISO8601DateFormatter().string(from: Date())
                let item = Item(
                    id: UUID().uuidString, subjectId: confirmed.subjectId,
                    unitId: confirmed.unitId, categoryId: confirmed.categoryId,
                    type: confirmed.type.rawValue, title: confirmed.title,
                    description: nil, dueDate: confirmed.dueDate, dueTime: nil,
                    priority: confirmed.priority.rawValue, source: "inbox_text",
                    status: ItemStatus.active.rawValue, createdAt: now, updatedAt: now
                )
                try ItemRepository(db: db).insert(item)
            }
            reset()
            loadRecentItems()
        } catch {
            showErrorMessage(error.localizedDescription)
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

        // Batch-resolve unique subject and unit IDs to avoid N+1 queries.
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
