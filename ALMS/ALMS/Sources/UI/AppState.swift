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
    let db: ALMSDatabase = .shared

    func checkFirstLaunch() {
        Task { await RemindersService.requestAccess() }
        Task { await CalendarService.requestAccess() }
        reindexSpotlightIfNeeded()
        NotificationService.requestPermission()
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
