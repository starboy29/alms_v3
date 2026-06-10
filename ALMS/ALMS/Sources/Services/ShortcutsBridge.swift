import Foundation

protocol ShortcutsBridging {
    func call(shortcutName: String, params: [String: Any]) throws -> String?
    func isInstalled(_ name: String) -> Bool
}

enum ShortcutsBridgeError: LocalizedError {
    case notInstalled(name: String)
    case executionFailed(name: String, stderr: String)
    case jsonSerializationFailed

    var errorDescription: String? {
        switch self {
        case .notInstalled(let n): return "Shortcut '\(n)' is not installed"
        case .executionFailed(let n, let err): return "Shortcut '\(n)' failed: \(err)"
        case .jsonSerializationFailed: return "Failed to serialize params to JSON"
        }
    }
}

struct ShortcutsBridge: ShortcutsBridging {
    private let shortcutsPath = "/usr/bin/shortcuts"

    func call(shortcutName: String, params: [String: Any]) throws -> String? {
        guard let jsonData = try? JSONSerialization.data(withJSONObject: params) else {
            throw ShortcutsBridgeError.jsonSerializationFailed
        }

        let tempFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("alms-\(UUID().uuidString).json")
        try jsonData.write(to: tempFile)
        defer { try? FileManager.default.removeItem(at: tempFile) }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: shortcutsPath)
        process.arguments = ["run", shortcutName, "--input-path", tempFile.path]

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            let errMsg = String(
                data: stderr.fileHandleForReading.readDataToEndOfFile(),
                encoding: .utf8
            ) ?? ""
            throw ShortcutsBridgeError.executionFailed(name: shortcutName, stderr: errMsg)
        }

        let output = stdout.fileHandleForReading.readDataToEndOfFile()
        return String(data: output, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nilIfEmpty
    }

    func isInstalled(_ name: String) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: shortcutsPath)
        process.arguments = ["list"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        guard (try? process.run()) != nil else { return false }
        process.waitUntilExit()
        let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        return output.contains(name)
    }
}

final class MockShortcutsBridge: ShortcutsBridging {
    var calls: [(name: String, params: [String: Any])] = []
    var shouldFail = false
    var failError: Error = ShortcutsBridgeError.executionFailed(name: "mock", stderr: "mock failure")
    var response: String? = nil

    func call(shortcutName: String, params: [String: Any]) throws -> String? {
        calls.append((name: shortcutName, params: params))
        if shouldFail { throw failError }
        return response
    }

    func isInstalled(_ name: String) -> Bool { true }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
