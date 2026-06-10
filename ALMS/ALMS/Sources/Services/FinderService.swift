import Foundation
import AppKit

struct FinderService {
    private let db: ALMSDatabase

    init(db: ALMSDatabase) { self.db = db }

    // MARK: - Security-scoped access to the user-chosen root folder

    private static let rootBookmarkKey = "root_folder_bookmark"

    /// Stores a security-scoped bookmark for the user-selected root folder. Requires the
    /// `com.apple.security.files.bookmarks.app-scope` entitlement (see ALMS.entitlements).
    static func saveRootBookmark(for url: URL) {
        if let data = try? url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        ) {
            UserDefaults.standard.set(data, forKey: rootBookmarkKey)
        }
    }

    /// Resolves the stored security-scoped bookmark to the root folder URL, if one exists.
    private func resolvedRootURL() -> URL? {
        guard let data = UserDefaults.standard.data(forKey: Self.rootBookmarkKey) else { return nil }
        var isStale = false
        guard let url = try? URL(
            resolvingBookmarkData: data,
            options: .withSecurityScope,
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) else { return nil }
        if isStale { Self.saveRootBookmark(for: url) }
        return url
    }

    /// Runs `body` while holding security-scoped access to the bookmarked root folder. The grant
    /// also covers subfolders, so creating the Semester/Subject/Chapter/Type tree and writing files
    /// inside it is permitted. If no bookmark exists (e.g. the default container path), runs as-is.
    private func withRootAccess<T>(_ body: () throws -> T) rethrows -> T {
        guard let url = resolvedRootURL() else { return try body() }
        let didAccess = url.startAccessingSecurityScopedResource()
        defer { if didAccess { url.stopAccessingSecurityScopedResource() } }
        return try body()
    }

    /// The root folder for filing. The bookmarked folder is authoritative when present — this keeps
    /// the path we build under exactly the folder we hold write access to, so they can never diverge.
    /// Falls back to the saved path / default only when no bookmark exists.
    func getRootPath() throws -> String {
        if let url = resolvedRootURL() { return url.path }
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
        // Hold security-scoped access to the bookmarked root for the whole operation so creating
        // the destination subfolders and writing the file are permitted by the sandbox.
        try withRootAccess {
            let destFolder = URL(fileURLWithPath: destPath).deletingLastPathComponent().path
            try ensureFolderExists(at: destFolder)
            if FileManager.default.fileExists(atPath: destPath) {
                try FileManager.default.removeItem(atPath: destPath)
            }
            try FileManager.default.moveItem(atPath: sourcePath, toPath: destPath)
            return destPath
        }
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
