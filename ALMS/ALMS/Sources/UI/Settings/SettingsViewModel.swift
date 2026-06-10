import Foundation
import AppKit

@Observable
final class SettingsViewModel {
    var rootFolder: String = ""
    var remindersList: String = "Inbox"
    var calendarName: String = "ALMS"
    var notesFolder: String = "ALMS"
    var notesAccount: String = "iCloud"
    var subjects: [Subject] = []
    var activeSemesterName: String = ""
    var showSavedAlert = false

    private let db: ALMSDatabase

    init(db: ALMSDatabase) {
        self.db = db
        load()
    }

    func load() {
        let repo = SettingsRepository(db: db)
        rootFolder    = (try? repo.getString(key: "root_folder"))    ?? ""
        remindersList = (try? repo.getString(key: "reminders_list")) ?? "Inbox"
        calendarName  = (try? repo.getString(key: "calendar_name"))  ?? "ALMS"
        notesFolder   = (try? repo.getString(key: "notes_folder"))   ?? "ALMS"
        notesAccount  = (try? repo.getString(key: "notes_account"))  ?? "iCloud"

        if let sem = try? SemesterRepository(db: db).fetchActive() {
            activeSemesterName = sem.name
            subjects = (try? SubjectRepository(db: db).fetchAll(semesterId: sem.id, includeArchived: false)) ?? []
        }
    }

    func save() {
        let repo = SettingsRepository(db: db)
        try? repo.set(key: "root_folder",    value: rootFolder)
        try? repo.set(key: "reminders_list", value: remindersList)
        try? repo.set(key: "calendar_name",  value: calendarName)
        try? repo.set(key: "notes_folder",   value: notesFolder)
        try? repo.set(key: "notes_account",  value: notesAccount)
        showSavedAlert = true
    }

    func pickFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Select Root Folder"
        if panel.runModal() == .OK, let url = panel.url {
            rootFolder = url.path
            // Persist a security-scoped bookmark so the sandbox keeps write access to this
            // folder across app launches — storing only the path would lose the grant on relaunch.
            FinderService.saveRootBookmark(for: url)
        }
    }

    func archiveSubject(id: String) {
        try? SubjectRepository(db: db).archive(id: id)
        load()
    }
}
