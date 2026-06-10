import SwiftUI

struct ContentView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var appState = appState
        NavigationSplitView(columnVisibility: .constant(.all)) {
            SidebarView()
        } detail: {
            switch appState.selectedTab {
            case .inbox:
                InboxView()
            case .dashboard:
                DashboardView()
            case .settings:
                SettingsView()
            }
        }
        .navigationSplitViewStyle(.balanced)
    }
}
