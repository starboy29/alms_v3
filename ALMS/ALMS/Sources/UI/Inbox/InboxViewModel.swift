import Foundation
import UniformTypeIdentifiers

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
    var recentItems: [Item] = []

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

    func loadRecentItems() {
        let all = (try? ItemRepository(db: db).fetchAll()) ?? []
        recentItems = Array(all.prefix(40))
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
