import Foundation

@Observable
final class DashboardViewModel {
    var upcomingItems: [Item] = []
    var allActiveItems: [Item] = []
    var recentActivity: [ActivityLog] = []
    var syncFailureCount: Int = 0

    private let db: ALMSDatabase

    init(db: ALMSDatabase) {
        self.db = db
        load()
    }

    func load() {
        allActiveItems = (try? ItemRepository(db: db).fetchAll(status: .active)) ?? []

        let cutoff = Calendar.current.date(byAdding: .day, value: 14, to: Date()) ?? Date()
        let cutoffStr = DateParser.iso8601Date(from: cutoff)
        let dueSoon = (try? ItemRepository(db: db).fetchDueBefore(cutoffStr)) ?? []
        upcomingItems = dueSoon.filter { $0.status == ItemStatus.active.rawValue }

        recentActivity = (try? ActivityLogRepository(db: db).fetchRecent(limit: 20)) ?? []
        syncFailureCount = (try? SyncLinkRepository(db: db).totalFailedCount()) ?? 0
    }

    func completeItem(_ id: String) {
        try? ItemRepository(db: db).complete(id: id)
        load()
    }

    func archiveItem(_ id: String) {
        try? ItemRepository(db: db).archive(id: id)
        load()
    }

    var itemsDueToday: [Item] {
        let today = DateParser.iso8601Date(from: Date())
        return allActiveItems.filter { $0.dueDate == today }
    }
}
