import SwiftUI

@main
struct ALMSApp: App {
    @State private var appState = AppState()
    private let quickEntry = QuickEntryManager(db: .shared)

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
                .onAppear {
                    appState.checkFirstLaunch()
                    quickEntry.setup()
                }
        }
        .defaultSize(width: 960, height: 640)
    }
}
