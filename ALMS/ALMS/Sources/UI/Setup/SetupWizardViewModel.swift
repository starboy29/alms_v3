import Foundation
import AppKit

@Observable
final class SetupWizardViewModel {
    var shortcuts: [ShortcutStatus] = []
    var isVerifying = false
    var expandedShortcut: String? = nil
    var isAutoInstalling = false
    var autoInstallMessage: String? = nil
    var terminalCommand: String? = nil
    let db: ALMSDatabase

    init(db: ALMSDatabase) {
        self.db = db
        verify()
    }

    func verify() {
        isVerifying = true
        shortcuts = ShortcutsVerifier().verify()
        isVerifying = false
    }

    func toggleExpanded(_ name: String) {
        expandedShortcut = expandedShortcut == name ? nil : name
    }

    var criticalCount: Int { shortcuts.filter { $0.isCritical }.count }
    var criticalInstalled: Int { shortcuts.filter { $0.isCritical && $0.isInstalled }.count }
    var allCriticalDone: Bool { criticalInstalled == criticalCount && criticalCount > 0 }
    var totalInstalled: Int { shortcuts.filter { $0.isInstalled }.count }

    func markSetupComplete() {
        try? SettingsRepository(db: db).set(key: "first_run_complete", value: true)
    }

    func openShortcutsApp() {
        NSWorkspace.shared.open(URL(string: "shortcuts://")!)
    }

    /// Generates the signed-install script and hands it to the user via Terminal.
    ///
    /// macOS only imports *signed* shortcut files, and `shortcuts sign` needs Keychain access that
    /// this sandboxed app cannot get — so ALMS itself can never install them. Instead we generate the
    /// files + a one-line command and run it in Terminal, where signing works with the user's identity.
    func autoInstall() {
        guard !isAutoInstalling else { return }
        isAutoInstalling = true
        terminalCommand = nil
        autoInstallMessage = "Preparing shortcuts…"

        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            do {
                let scriptURL = try ShortcutFileGenerator.generateInstallScript()
                let cmd = "bash '\(scriptURL.path)'"

                await MainActor.run {
                    // Copy the command so the user can paste it straight into Terminal.
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(cmd, forType: .string)

                    self.terminalCommand = cmd
                    self.autoInstallMessage = "Command copied. Terminal is open — paste (⌘V) and press Return, then tap Verify Now."
                    self.isAutoInstalling = false

                    NSWorkspace.shared.open(
                        URL(fileURLWithPath: "/System/Applications/Utilities/Terminal.app")
                    )
                }
            } catch {
                await MainActor.run {
                    self.autoInstallMessage = "Error preparing shortcuts: \(error.localizedDescription)"
                    self.isAutoInstalling = false
                }
            }
        }
    }

    func copyTerminalCommand() {
        guard let cmd = terminalCommand else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(cmd, forType: .string)
    }

    static func needsSetup(db: ALMSDatabase) -> Bool {
        !((try? SettingsRepository(db: db).getBool(key: "first_run_complete", default: false)) ?? false)
    }
}
