import AppKit
import Foundation

struct SyncFailure: Identifiable {
    let id: String
    let itemId: String
    let itemTitle: String
    let integration: String
    let errorMessage: String?
    let retryCount: Int
}

@Observable
final class DashboardViewModel {
    var upcomingItems: [Item] = []
    var allActiveItems: [Item] = []
    var dueSoonItems: [Item] = []
    var recentActivity: [ActivityLog] = []
    var syncFailureCount: Int = 0
    var failedSyncs: [SyncFailure] = []
    var showSyncIssues = false

    private let db: ALMSDatabase

    init(db: ALMSDatabase) {
        self.db = db
        load()
    }

    func load() {
        allActiveItems = (try? ItemRepository(db: db).fetchAll(status: .active)) ?? []
        dueSoonItems = (try? ItemRepository(db: db).fetchDueSoon(withinDays: 7)) ?? []

        let cutoff = Calendar.current.date(byAdding: .day, value: 14, to: Date()) ?? Date()
        let cutoffStr = DateParser.iso8601Date(from: cutoff)
        let dueSoon = (try? ItemRepository(db: db).fetchDueBefore(cutoffStr)) ?? []
        upcomingItems = dueSoon.filter { $0.status == ItemStatus.active.rawValue }

        recentActivity = (try? ActivityLogRepository(db: db).fetchRecent(limit: 20)) ?? []
        syncFailureCount = (try? SyncLinkRepository(db: db).totalFailedCount()) ?? 0
        loadFailedSyncs()
    }

    func retrySync(itemId: String) {
        try? RoutingEngine(db: db).retryFailed(itemId: itemId)
        load()
    }

    private func loadFailedSyncs() {
        let sync = SyncLinkRepository(db: db)
        let itemRepo = ItemRepository(db: db)
        var syncs: [SyncFailure] = []
        for link in (try? sync.fetchFailedReminderLinks()) ?? [] {
            let title = (try? itemRepo.fetchById(link.itemId))?.title ?? link.reminderTitle
            syncs.append(SyncFailure(id: link.id, itemId: link.itemId, itemTitle: title,
                                     integration: "Reminder", errorMessage: link.errorMessage,
                                     retryCount: link.retryCount))
        }
        for link in (try? sync.fetchFailedCalendarLinks()) ?? [] {
            let title = (try? itemRepo.fetchById(link.itemId))?.title ?? link.eventTitle
            syncs.append(SyncFailure(id: link.id, itemId: link.itemId, itemTitle: title,
                                     integration: "Calendar", errorMessage: link.errorMessage,
                                     retryCount: link.retryCount))
        }
        failedSyncs = syncs
    }

    func completeItem(_ id: String) {
        try? ItemRepository(db: db).complete(id: id)
        SpotlightService().deindex(itemId: id)
        load()
    }

    func archiveItem(_ id: String) {
        try? ItemRepository(db: db).archive(id: id)
        SpotlightService().deindex(itemId: id)
        load()
    }

    func hasFile(itemId: String) -> Bool {
        (try? FileRepository(db: db).fetchByItemId(itemId)) != nil
    }

    func revealInFinder(itemId: String) {
        guard let file = try? FileRepository(db: db).fetchByItemId(itemId) else { return }
        NSWorkspace.shared.selectFile(file.storedPath, inFileViewerRootedAtPath: "")
    }

    var itemsDueToday: [Item] {
        let today = DateParser.iso8601Date(from: Date())
        return allActiveItems.filter { $0.dueDate == today }
    }

    var overdueItems: [Item] {
        let today = DateParser.iso8601Date(from: Date())
        return allActiveItems.filter { item in
            guard let due = item.dueDate else { return false }
            return due < today
        }
    }
}
