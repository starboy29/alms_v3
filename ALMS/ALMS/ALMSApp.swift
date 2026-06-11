import SwiftUI
import ServiceManagement

@main
struct ALMSApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var appState = AppState()
    @State private var launchAtLogin = (SMAppService.mainApp.status == .enabled)
    private let quickEntry = QuickEntryManager(db: .shared)

    var body: some Scene {
        WindowGroup(id: "main") {
            ContentView()
                .environment(appState)
                .onAppear {
                    appState.checkFirstLaunch()
                    quickEntry.setup()
                }
        }
        .defaultSize(width: 960, height: 640)

        MenuBarExtra("ALMS", systemImage: "tray.and.arrow.down") {
            ALMSMenuBarMenu(launchAtLogin: $launchAtLogin)
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide from Dock — app lives in the menu bar
        NSApp.setActivationPolicy(.accessory)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Keep running in background when the main window is closed
        return false
    }
}

struct ALMSMenuBarMenu: View {
    @Binding var launchAtLogin: Bool
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("Open ALMS") {
            openWindow(id: "main")
            NSApp.activate(ignoringOtherApps: true)
        }
        .keyboardShortcut("o")

        Divider()

        Toggle("Launch at Login", isOn: $launchAtLogin)
            .onChange(of: launchAtLogin) { _, enabled in
                if enabled {
                    try? SMAppService.mainApp.register()
                } else {
                    try? SMAppService.mainApp.unregister()
                }
            }

        Divider()

        Button("Quit ALMS") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}
