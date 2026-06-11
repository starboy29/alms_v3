import Foundation
import EventKit

struct CalendarService {

    enum CalendarError: LocalizedError {
        case accessDenied
        case accessRequested
        case noSource

        var errorDescription: String? {
            switch self {
            case .accessRequested:
                return "Requesting Calendar access — please approve the prompt, then add this item again."
            case .accessDenied:
                return "ALMS doesn't have permission to use Calendar. Enable it in System Settings → Privacy & Security → Calendars, then try again."
            case .noSource:
                return "No Calendar account is available to create the calendar in."
            }
        }
    }

    @discardableResult
    static func requestAccess() async -> Bool {
        let store = EKEventStore()
        if #available(macOS 14.0, *) {
            return (try? await store.requestFullAccessToEvents()) ?? false
        } else {
            return await withCheckedContinuation { continuation in
                store.requestAccess(to: .event) { granted, _ in continuation.resume(returning: granted) }
            }
        }
    }

    static var isAuthorized: Bool {
        let status = EKEventStore.authorizationStatus(for: .event)
        if #available(macOS 14.0, *) { return status == .fullAccess }
        return status == .authorized
    }

    func createEvent(title: String, calendarName: String, date: Date, notes: String?) throws {
        guard Self.isAuthorized else {
            if EKEventStore.authorizationStatus(for: .event) == .notDetermined {
                Task { await Self.requestAccess() }
                throw CalendarError.accessRequested
            }
            throw CalendarError.accessDenied
        }

        let store = EKEventStore()
        let calendar = try ensureCalendar(named: calendarName, store: store)

        let event = EKEvent(eventStore: store)
        event.title = title
        event.calendar = calendar
        event.isAllDay = true
        event.startDate = date
        event.endDate = date
        event.notes = notes

        try store.save(event, span: .thisEvent, commit: true)
    }

    private func ensureCalendar(named name: String, store: EKEventStore) throws -> EKCalendar {
        if let existing = store.calendars(for: .event)
            .first(where: { $0.title.caseInsensitiveCompare(name) == .orderedSame }) {
            return existing
        }
        let calendar = EKCalendar(for: .event, eventStore: store)
        calendar.title = name
        guard let source = store.defaultCalendarForNewEvents?.source
                ?? store.sources.first(where: { $0.sourceType == .calDAV })
                ?? store.sources.first(where: { $0.sourceType == .local })
                ?? store.sources.first else {
            throw CalendarError.noSource
        }
        calendar.source = source
        try store.saveCalendar(calendar, commit: true)
        return calendar
    }
}
