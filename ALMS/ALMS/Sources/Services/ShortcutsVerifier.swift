import Foundation

struct ShortcutStatus: Identifiable {
    let name: String
    let description: String
    let appleApp: String
    let isCritical: Bool
    var isInstalled: Bool

    var id: String { name }
}

struct ShortcutsVerifier {
    static let required: [ShortcutStatus] = [
        ShortcutStatus(
            name: "ALMS-CreateCalendarEvent",
            description: "Creates a new event in Apple Calendar",
            appleApp: "Calendar",
            isCritical: true,
            isInstalled: false
        ),
    ]

    func verify() -> [ShortcutStatus] {
        let installed = listInstalled()
        return Self.required.map { shortcut in
            var s = shortcut
            s.isInstalled = installed.contains(shortcut.name)
            return s
        }
    }

    private func listInstalled() -> Set<String> {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")
        process.arguments = ["list"]
        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe
        guard (try? process.run()) != nil else { return [] }
        process.waitUntilExit()
        let output = String(
            data: outPipe.fileHandleForReading.readDataToEndOfFile(),
            encoding: .utf8
        ) ?? ""
        let lines = output
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
        return Set(lines.filter { $0.hasPrefix("ALMS-") })
    }
}
