import Foundation
import EventKit

/// Creates reminders directly via EventKit (instead of the Shortcuts CLI). This lets ALMS choose the
/// list, create it if missing, set a real due date, and add organizing #tags — none of which the
/// "Add New Reminder" shortcut action does reliably on macOS Tahoe.
struct RemindersService {

    enum RemindersError: LocalizedError {
        case accessRequested
        case accessDenied
        case noSource

        var errorDescription: String? {
            switch self {
            case .accessRequested:
                return "Requesting Reminders access — please approve the prompt, then add this item again."
            case .accessDenied:
                return "ALMS doesn't have permission to use Reminders. Enable it in System Settings → Privacy & Security → Reminders, then try again."
            case .noSource:
                return "No Reminders account is available to create the list in."
            }
        }
    }

    /// Requests Reminders access, showing the system prompt on first call. Call once at app launch so
    /// access is already granted by the time a reminder is created (keeps `createReminder` synchronous).
    @discardableResult
    static func requestAccess() async -> Bool {
        let store = EKEventStore()
        if #available(macOS 14.0, *) {
            return (try? await store.requestFullAccessToReminders()) ?? false
        } else {
            return await withCheckedContinuation { continuation in
                store.requestAccess(to: .reminder) { granted, _ in continuation.resume(returning: granted) }
            }
        }
    }

    static var isAuthorized: Bool {
        let status = EKEventStore.authorizationStatus(for: .reminder)
        if #available(macOS 14.0, *) { return status == .fullAccess }
        return status == .authorized
    }

    /// Creates a reminder in `listName` (creating the list if it doesn't exist) with an optional due
    /// date and #tags appended to the notes. Synchronous — assumes access was granted at launch.
    func createReminder(title: String, listName: String, dueDate: Date?, tags: [String]) throws {
        guard Self.isAuthorized else {
            // If we've never asked (or the prompt was missed), trigger it now so the next attempt works.
            // We can't block the main thread waiting for the prompt, so surface a "try again" message.
            if EKEventStore.authorizationStatus(for: .reminder) == .notDetermined {
                Task { await Self.requestAccess() }
                throw RemindersError.accessRequested
            }
            throw RemindersError.accessDenied
        }

        let store = EKEventStore()
        let calendar = try ensureList(named: listName, store: store)

        let reminder = EKReminder(eventStore: store)
        reminder.calendar = calendar
        reminder.notes = "Added via ALMS"

        // EventKit has no API for real tags. The only way to create real (smart-stackable) Reminders
        // tags programmatically is to append #hashtags to the TITLE — Reminders' parser converts them
        // into tag chips on Tahoe (hashtags in NOTES are NOT parsed, which is why they showed as text).
        let tokens = tags.compactMap(Self.tagToken)
        if tokens.isEmpty {
            reminder.title = title
        } else {
            reminder.title = title + " " + tokens.map { "#\($0)" }.joined(separator: " ")
        }

        if let due = dueDate {
            let cal = Calendar.current
            reminder.dueDateComponents = cal.dateComponents([.year, .month, .day], from: due)
            // A morning alarm so the reminder actually notifies on its due day.
            if let alarmDate = cal.date(bySettingHour: 9, minute: 0, second: 0, of: due) {
                reminder.addAlarm(EKAlarm(absoluteDate: alarmDate))
            }
        }

        try store.save(reminder, commit: true)
    }

    /// Finds the reminders list by name (case-insensitive) or creates it.
    private func ensureList(named name: String, store: EKEventStore) throws -> EKCalendar {
        if let existing = store.calendars(for: .reminder)
            .first(where: { $0.title.caseInsensitiveCompare(name) == .orderedSame }) {
            return existing
        }
        let calendar = EKCalendar(for: .reminder, eventStore: store)
        calendar.title = name
        // Prefer the account that hosts the default reminders list (usually iCloud), then any usable source.
        guard let source = store.defaultCalendarForNewReminders()?.source
                ?? store.sources.first(where: { $0.sourceType == .calDAV })
                ?? store.sources.first(where: { $0.sourceType == .local })
                ?? store.sources.first else {
            throw RemindersError.noSource
        }
        calendar.source = source
        try store.saveCalendar(calendar, commit: true)
        return calendar
    }

    /// Reduces a string to a valid hashtag token (alphanumerics only — Reminders tags can't contain spaces).
    private static func tagToken(_ raw: String) -> String? {
        let token = raw.unicodeScalars
            .filter { CharacterSet.alphanumerics.contains($0) }
            .map(String.init)
            .joined()
        return token.isEmpty ? nil : token
    }
}
