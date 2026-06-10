import Foundation
import GRDB

struct DefaultSeedData {
    private let db: ALMSDatabase

    init(db: ALMSDatabase) { self.db = db }

    func seedIfNeeded() throws {
        guard !db.isInMemory else { return }

        let settingsRepo = SettingsRepository(db: db)
        let alreadySeeded = (try? settingsRepo.getBool(key: "seed_complete")) ?? false
        guard !alreadySeeded else { return }

        try seedDefaultSemester()
        try seedDefaultSettings()
        try settingsRepo.set(key: "seed_complete", value: true)
    }

    private func seedDefaultSemester() throws {
        let semesterRepo = SemesterRepository(db: db)
        let subjectRepo = SubjectRepository(db: db)
        let unitRepo = UnitRepository(db: db)
        let categoryRepo = CategoryRepository(db: db)

        let semesterId = UUID().uuidString
        var semester = Semester(
            id: semesterId,
            name: "Semester 5",
            startDate: nil,
            endDate: nil,
            isActive: true,
            createdAt: now(),
            updatedAt: now()
        )
        try semesterRepo.insert(&semester)

        let defaultSubjects: [(String, String)] = [
            ("ANN", "ANN"),
            ("ML", "Machine Learning"),
            ("CN", "Computer Networks"),
            ("FLA", "FLA"),
            ("MATH", "Mathematics"),
            ("SRW", "Short Range Wireless"),
            ("IAF", "Indian Art Form"),
            ("CC", "Community Connect")
        ]

        for (i, (code, name)) in defaultSubjects.enumerated() {
            let subjectId = UUID().uuidString
            let subject = Subject(
                id: subjectId,
                semesterId: semesterId,
                name: name,
                code: code,
                color: nil,
                archived: false,
                sortOrder: i,
                createdAt: now(),
                updatedAt: now()
            )
            try subjectRepo.insert(subject)
            try unitRepo.createDefaultUnits(subjectId: subjectId, count: 5)

            let units = try unitRepo.fetchAll(subjectId: subjectId)
            for unit in units {
                try categoryRepo.createDefaultCategories(unitId: unit.id)
            }
        }
    }

    private func seedDefaultSettings() throws {
        let repo = SettingsRepository(db: db)
        let iCloudRoot = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .deletingLastPathComponent()
            .appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs/ALMS")
            .path
        try repo.set(key: "root_folder", value: iCloudRoot)
        try repo.set(key: "current_semester", value: "Semester 5")
        try repo.set(key: "reminders_list", value: "Inbox")
        try repo.set(key: "calendar_name", value: "ALMS")
        try repo.set(key: "notes_folder", value: "ALMS")
        try repo.set(key: "notes_account", value: "iCloud")
        try repo.set(key: "file_renaming_enabled", value: true)
        try repo.set(key: "units_per_subject", value: 5)
        try repo.set(key: "max_retry_count", value: 3)
        try repo.set(key: "shortcut_invocation", value: "cli")
        try repo.set(key: "first_run_complete", value: false)
    }

    private func now() -> String { ISO8601DateFormatter().string(from: Date()) }
}
