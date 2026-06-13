import Foundation

enum AppTab: String, CaseIterable, Identifiable {
    case inbox = "Inbox"
    case dashboard = "Dashboard"
    case settings = "Settings"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .inbox: return "tray.and.arrow.down"
        case .dashboard: return "rectangle.3.group"
        case .settings: return "gear"
        }
    }
}

@Observable
final class AppState {
    var selectedTab: AppTab = .inbox
    var quickEntryPendingText: String?
    var quickEntryPendingFilePath: String?
    let db: ALMSDatabase = .shared

    func checkFirstLaunch() {
        Task { await RemindersService.requestAccess() }
        Task { await CalendarService.requestAccess() }
        reindexSpotlightIfNeeded()
        NotificationService.requestPermission()
        DueDateWarningService(db: db).checkAndNotifyIfNeeded()
        observeQuickEntryFile()
    }

    private func observeQuickEntryFile() {
        NotificationCenter.default.addObserver(
            forName: .quickEntryFilePending,
            object: nil,
            queue: .main
        ) { [weak self] note in
            self?.selectedTab = .inbox
            self?.quickEntryPendingFilePath = note.object as? String
        }
    }

    private func reindexSpotlightIfNeeded() {
        let key = "spotlight_indexed_v1"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        Task {
            SpotlightService().reindexAll(db: db)
            UserDefaults.standard.set(true, forKey: key)
        }
    }

    func forceReindexSpotlight() {
        UserDefaults.standard.removeObject(forKey: "spotlight_indexed_v1")
        Task { SpotlightService().reindexAll(db: db) }
    }
}

extension Notification.Name {
    static let quickEntryFilePending = Notification.Name("com.alms.quickEntryFilePending")
}
