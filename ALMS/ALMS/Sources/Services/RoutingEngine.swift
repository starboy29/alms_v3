import Foundation

struct RoutingTarget {
    enum App: String { case reminders, calendar, notes, finder }
    enum Action: String { case create, update, skip }

    let app: App
    let action: Action
    let reason: String
}

struct RoutingEngine {
    private let db: ALMSDatabase
    private let bridge: ShortcutsBridging

    init(db: ALMSDatabase, bridge: ShortcutsBridging) {
        self.db = db
        self.bridge = bridge
    }

    func route(item: Item) -> [RoutingTarget] {
        guard let type = ItemType(rawValue: item.type) else { return [] }

        switch type {
        case .assignment, .exam, .lab, .project:
            var targets = [RoutingTarget(app: .reminders, action: .create, reason: "Due-date item")]
            if item.dueDate != nil {
                targets.append(RoutingTarget(app: .calendar, action: .create, reason: "Has due date"))
            }
            return targets
        case .notes:
            // Notes routing is disabled (Apple Notes shortcut intentionally not installed) —
            // capture note-type items as reminders so nothing is silently dropped.
            return [RoutingTarget(app: .reminders, action: .create, reason: "Notes type → reminder")]
        case .event:
            return [RoutingTarget(app: .calendar, action: .create, reason: "Event type")]
        case .resource, .other:
            return []
        }
    }

    func execute(itemId: String, targets: [RoutingTarget]) throws {
        guard let item = try ItemRepository(db: db).fetchById(itemId) else { return }

        let settings = SettingsRepository(db: db)
        let remindersList = (try? settings.getString(key: "reminders_list")) ?? "Inbox"
        let calendarName  = (try? settings.getString(key: "calendar_name"))  ?? "ALMS"
        let sync = SyncLinkRepository(db: db)
        let logger = ActivityLogRepository(db: db)
        let now = ISO8601DateFormatter().string(from: Date())

        for target in targets {
            switch target.app {
            case .reminders:
                try handleReminder(item: item, listName: remindersList,
                                   sync: sync, logger: logger, now: now)
            case .calendar:
                try handleCalendar(item: item, calendarName: calendarName,
                                   sync: sync, logger: logger, now: now)
            case .notes, .finder:
                // Notes routing is disabled (note-type items are routed to reminders in route()).
                // Finder filing is handled natively at import time by InboxService/FinderService.
                break
            }
        }
    }

    func retryFailed(itemId: String) throws {
        guard let item = try ItemRepository(db: db).fetchById(itemId) else { return }
        let targets = route(item: item)
        try execute(itemId: itemId, targets: targets)
    }

    private func handleReminder(
        item: Item, listName: String,
        sync: SyncLinkRepository, logger: ActivityLogRepository, now: String
    ) throws {
        // Resolve subject once — used for both the title prefix and the #tag.
        let subject = (try? SubjectRepository(db: db).fetchById(item.subjectId)) ?? nil
        let subjectLabel = subject.map { $0.code?.isEmpty == false ? $0.code! : $0.name }

        // "ANN: assignment 2"
        let reminderTitle = subjectLabel.map { "\($0): \(item.title)" } ?? item.title

        let link = ReminderLink(
            id: UUID().uuidString, itemId: item.id, reminderExtId: nil,
            reminderTitle: reminderTitle, listName: listName,
            status: SyncStatus.pending.rawValue,
            lastSyncedAt: nil, errorMessage: nil, retryCount: 0,
            createdAt: now, updatedAt: now
        )
        try sync.upsertReminderLink(link)

        // Organizing #tags: #ALMS marker, subject, type, chapter/unit.
        var tags = ["ALMS"]
        if let label = subjectLabel { tags.append(label) }
        tags.append(item.type)
        if let unitId = item.unitId,
           let unit = (try? UnitRepository(db: db).fetchById(unitId)) ?? nil {
            tags.append(unit.name)
        }

        let due = item.dueDate.flatMap(Self.parseDate)

        do {
            try RemindersService().createReminder(
                title: reminderTitle, listName: listName, dueDate: due, tags: tags
            )
            try sync.updateReminderLinkStatus(itemId: item.id, status: .created, error: nil)
            logger.log(eventType: .shortcutCall, entityId: item.id,
                       details: "Created reminder: \(reminderTitle)")
        } catch {
            try sync.updateReminderLinkStatus(itemId: item.id, status: .failed,
                                              error: error.localizedDescription)
            logger.log(eventType: .runtimeError, entityId: item.id,
                       details: "Reminder failed", errorMessage: error.localizedDescription)
        }
    }

    /// Parses a "yyyy-MM-dd" due-date string into a Date.
    private static func parseDate(_ string: String) -> Date? {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f.date(from: string)
    }

    private func handleCalendar(
        item: Item, calendarName: String,
        sync: SyncLinkRepository, logger: ActivityLogRepository, now: String
    ) throws {
        let subject = (try? SubjectRepository(db: db).fetchById(item.subjectId)) ?? nil
        let subjectLabel = subject.map { $0.code?.isEmpty == false ? $0.code! : $0.name }

        // "ANN: assignment 2 Due"
        let eventTitle = (subjectLabel.map { "\($0): \(item.title)" } ?? item.title) + " Due"

        let eventDate = item.dueDate ?? DateParser.iso8601Date(from: Date())
        let link = CalendarLink(
            id: UUID().uuidString, itemId: item.id, eventExtId: nil,
            eventTitle: eventTitle, calendarName: calendarName,
            eventDate: eventDate, allDay: true,
            status: SyncStatus.pending.rawValue,
            lastSyncedAt: nil, errorMessage: nil, retryCount: 0,
            createdAt: now, updatedAt: now
        )
        try sync.upsertCalendarLink(link)

        let params: [String: Any] = [
            "title": eventTitle,
            "start_date": eventDate,
            "all_day": true,
            "calendar": calendarName,
            "notes": "Added via ALMS"
        ]

        do {
            _ = try bridge.call(shortcutName: "ALMS-CreateCalendarEvent", params: params)
            try sync.updateCalendarLinkStatus(itemId: item.id, status: .created, error: nil)
            logger.log(eventType: .shortcutCall, entityId: item.id,
                       details: "Created calendar event: \(item.title)")
        } catch {
            try sync.updateCalendarLinkStatus(itemId: item.id, status: .failed,
                                              error: error.localizedDescription)
            logger.log(eventType: .runtimeError, entityId: item.id,
                       details: "Calendar event failed", errorMessage: error.localizedDescription)
        }
    }

}
