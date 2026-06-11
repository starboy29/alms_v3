import Foundation
import AppKit

struct FinderService {
    private let db: ALMSDatabase

    init(db: ALMSDatabase) { self.db = db }

    func getRootPath() throws -> String {
        let repo = SettingsRepository(db: db)
        return try repo.getString(key: "root_folder") ?? defaultRootPath()
    }

    func buildPath(
        semester: String? = nil,
        subjectCode: String,
        unitName: String? = nil,
        categoryName: String? = nil
    ) throws -> String {
        let root = try getRootPath()
        var components = [root]
        if let s = semester {
            components.append(s.replacingOccurrences(of: " ", with: ""))
        }
        components.append(subjectCode)
        if let u = unitName {
            components.append(u.replacingOccurrences(of: " ", with: ""))
        }
        if let c = categoryName {
            components.append(c)
        }
        return components.joined(separator: "/")
    }

    func ensureFolderExists(at path: String) throws {
        try FileManager.default.createDirectory(
            atPath: path,
            withIntermediateDirectories: true,
            attributes: nil
        )
    }

    @discardableResult
    func moveFile(from sourcePath: String, to destPath: String) throws -> String {
        let destFolder = URL(fileURLWithPath: destPath).deletingLastPathComponent().path
        try ensureFolderExists(at: destFolder)
        if FileManager.default.fileExists(atPath: destPath) {
            try FileManager.default.removeItem(atPath: destPath)
        }
        try FileManager.default.moveItem(atPath: sourcePath, toPath: destPath)
        return destPath
    }

    func fileExists(at path: String) -> Bool {
        FileManager.default.fileExists(atPath: path)
    }

    func revealInFinder(path: String) {
        NSWorkspace.shared.selectFile(path, inFileViewerRootedAtPath: "")
    }

    private func defaultRootPath() -> String {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ALMS").path
    }
}
