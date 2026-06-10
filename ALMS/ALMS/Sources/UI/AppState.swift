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
    var showSetupWizard: Bool = false
    let db: ALMSDatabase = .shared

    func checkFirstLaunch() {
        showSetupWizard = SetupWizardViewModel.needsSetup(db: db)
        // Prompt for Reminders access early so it's granted before the first reminder is created
        // (RemindersService.createReminder is synchronous and assumes access is already authorized).
        Task { await RemindersService.requestAccess() }
    }
}
