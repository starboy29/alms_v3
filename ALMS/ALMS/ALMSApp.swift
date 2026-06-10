import SwiftUI

@main
struct ALMSApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
                .sheet(isPresented: Binding(
                    get: { appState.showSetupWizard },
                    set: { appState.showSetupWizard = $0 }
                )) {
                    SetupWizardView(db: appState.db) {
                        appState.showSetupWizard = false
                    }
                }
                .onAppear {
                    appState.checkFirstLaunch()
                }
        }
        .defaultSize(width: 960, height: 640)
    }
}
