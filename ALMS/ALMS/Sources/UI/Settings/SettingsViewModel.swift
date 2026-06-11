import Foundation
import AppKit

@Observable
final class SettingsViewModel {
    var rootFolder: String = ""
    var remindersList: String = "Inbox"
    var calendarName: String = "ALMS"
    var subjects: [Subject] = []
    var semesters: [Semester] = []
    var activeSemesterName: String = ""
    var showSavedAlert = false
    var showNewSemester = false
    var newSemesterName = ""
    var showNewSubject = false
    var newSubjectCode = ""
    var newSubjectName = ""

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

        semesters = (try? SemesterRepository(db: db).fetchAll()) ?? []
        if let sem = try? SemesterRepository(db: db).fetchActive() {
            activeSemesterName = sem.name
            subjects = (try? SubjectRepository(db: db).fetchAll(semesterId: sem.id, includeArchived: false)) ?? []
        }
    }

    func addSemester() {
        let name = newSemesterName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        let ts = ISO8601DateFormatter().string(from: Date())
        var sem = Semester(id: UUID().uuidString, name: name, startDate: nil, endDate: nil,
                           isActive: false, createdAt: ts, updatedAt: ts)
        try? SemesterRepository(db: db).insert(&sem)
        newSemesterName = ""
        showNewSemester = false
        load()
    }

    func switchSemester(id: String) {
        try? SemesterRepository(db: db).setActive(id: id)
        load()
    }

    func save() {
        let repo = SettingsRepository(db: db)
        try? repo.set(key: "root_folder",    value: rootFolder)
        try? repo.set(key: "reminders_list", value: remindersList)
        try? repo.set(key: "calendar_name",  value: calendarName)
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

    func addSubject() {
        let name = newSubjectName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, let sem = try? SemesterRepository(db: db).fetchActive() else { return }
        let code = newSubjectCode.trimmingCharacters(in: .whitespacesAndNewlines)
        let ts = ISO8601DateFormatter().string(from: Date())
        let subjectId = UUID().uuidString
        let subject = Subject(
            id: subjectId, semesterId: sem.id,
            name: name, code: code.isEmpty ? nil : code,
            color: nil, archived: false, sortOrder: subjects.count,
            createdAt: ts, updatedAt: ts
        )
        guard (try? SubjectRepository(db: db).insert(subject)) != nil else { return }
        let unitRepo = UnitRepository(db: db)
        let catRepo = CategoryRepository(db: db)
        try? unitRepo.createDefaultUnits(subjectId: subjectId, count: 5)
        if let units = try? unitRepo.fetchAll(subjectId: subjectId) {
            for unit in units { try? catRepo.createDefaultCategories(unitId: unit.id) }
        }
        newSubjectCode = ""
        newSubjectName = ""
        showNewSubject = false
        load()
    }

    func archiveSubject(id: String) {
        try? SubjectRepository(db: db).archive(id: id)
        load()
    }
}
