import SwiftUI

struct SidebarView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var appState = appState
        List(AppTab.allCases, selection: $appState.selectedTab) { tab in
            Label(tab.rawValue, systemImage: tab.icon)
                .tag(tab)
        }
        .listStyle(.sidebar)
        .navigationTitle("ALMS")
        .navigationSplitViewColumnWidth(min: 160, ideal: 200, max: 220)
    }
}
