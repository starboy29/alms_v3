import Foundation

struct DueDateWarningService {
    private let db: ALMSDatabase
    private static let lastCheckedKey = "due_warning_last_checked_date"

    init(db: ALMSDatabase) { self.db = db }

    func checkAndNotifyIfNeeded() {
        let today = DateParser.iso8601Date(from: Date())
        guard UserDefaults.standard.string(forKey: Self.lastCheckedKey) != today else { return }

        guard let items = try? ItemRepository(db: db).fetchDueSoon(withinDays: 7),
              !items.isEmpty else { return }

        UserDefaults.standard.set(today, forKey: Self.lastCheckedKey)

        let subjectRepo = SubjectRepository(db: db)
        var countByCode: [String: Int] = [:]
        for item in items {
            let code = (try? subjectRepo.fetchById(item.subjectId))?.code ?? "?"
            countByCode[code, default: 0] += 1
        }

        let summary = countByCode
            .sorted { $0.value > $1.value }
            .prefix(4)
            .map { "\($0.key) (\($0.value))" }
            .joined(separator: ", ")

        NotificationService.send(
            title: "Due this week",
            body: "\(items.count) item\(items.count == 1 ? "" : "s") — \(summary)"
        )
    }
}
