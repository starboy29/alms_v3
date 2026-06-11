import SwiftUI

struct ItemDetailView: View {
    let row: InboxRow
    let db: ALMSDatabase
    let onRetry: () -> Void

    @State private var reminderLink: ReminderLink?
    @State private var calendarLink: CalendarLink?
    @State private var file: ALMSFile?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerBar
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    metaSection
                    syncSection
                    if file != nil { fileSection }
                }
                .padding(20)
            }
        }
        .frame(minWidth: 420, minHeight: 320)
        .onAppear { loadDetails() }
    }

    private var headerBar: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(row.item.title)
                    .font(.title2.weight(.semibold))
                    .lineLimit(3)
                HStack(spacing: 6) {
                    if let code = row.subjectCode { SubjectPill(code: code) }
                    TypeBadge(type: row.item.type)
                    if let unit = row.unitName {
                        Text(unit)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 4))
                    }
                }
            }
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary).font(.title3)
            }
            .buttonStyle(.plain)
        }
        .padding(20)
    }

    private var metaSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Details", systemImage: "info.circle").font(.headline)
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 6) {
                if let due = row.item.dueDate {
                    GridRow {
                        Text("Due").foregroundStyle(.secondary).font(.callout)
                        Text(formattedDate(due)).font(.callout)
                    }
                }
                GridRow {
                    Text("Priority").foregroundStyle(.secondary).font(.callout)
                    Text(row.item.priority.capitalized).font(.callout)
                }
                GridRow {
                    Text("Status").foregroundStyle(.secondary).font(.callout)
                    Text(row.item.status.capitalized).font(.callout)
                }
                GridRow {
                    Text("Added").foregroundStyle(.secondary).font(.callout)
                    Text(formattedTimestamp(row.item.createdAt)).font(.callout)
                }
            }
            .padding(12)
            .background(.background)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.secondary.opacity(0.15)))
        }
    }

    private var syncSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Sync Status", systemImage: "arrow.triangle.2.circlepath").font(.headline)
            VStack(spacing: 0) {
                if let r = reminderLink {
                    syncRow(icon: "bell.fill", label: "Reminder",
                            status: r.status, detail: r.listName,
                            error: r.errorMessage, itemId: r.itemId)
                    if calendarLink != nil { Divider().padding(.leading, 40) }
                }
                if let c = calendarLink {
                    syncRow(icon: "calendar", label: "Calendar",
                            status: c.status, detail: c.calendarName,
                            error: c.errorMessage, itemId: c.itemId)
                }
                if reminderLink == nil && calendarLink == nil {
                    Text("No sync targets for this item type.")
                        .foregroundStyle(.secondary).font(.callout).padding(12)
                }
            }
            .background(.background)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.secondary.opacity(0.15)))
        }
    }

    @ViewBuilder
    private func syncRow(icon: String, label: String, status: String,
                         detail: String, error: String?, itemId: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(statusColor(status))
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(label).font(.callout)
                    Text("· \(detail)").font(.callout).foregroundStyle(.secondary)
                }
                if let err = error {
                    Text(err).font(.caption).foregroundStyle(.red).lineLimit(2)
                }
            }
            Spacer()
            HStack(spacing: 8) {
                statusBadge(status)
                if status == SyncStatus.failed.rawValue {
                    Button("Retry") {
                        try? RoutingEngine(db: db).retryFailed(itemId: itemId)
                        onRetry()
                        loadDetails()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
    }

    private var fileSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("File", systemImage: "doc").font(.headline)
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(file!.originalName).font(.callout).lineLimit(1)
                    Text(file!.storedPath).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer()
                Button("Reveal in Finder") {
                    NSWorkspace.shared.selectFile(file!.storedPath, inFileViewerRootedAtPath: "")
                }
                .buttonStyle(.bordered)
            }
            .padding(12)
            .background(.background)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.secondary.opacity(0.15)))
        }
    }

    private func statusBadge(_ status: String) -> some View {
        Text(status.capitalized)
            .font(.caption).fontWeight(.medium)
            .foregroundStyle(statusColor(status))
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(statusColor(status).opacity(0.12), in: RoundedRectangle(cornerRadius: 4))
    }

    private func statusColor(_ status: String) -> Color {
        switch SyncStatus(rawValue: status) {
        case .created: return .green
        case .failed:  return .red
        case .pending: return .orange
        default:       return .secondary
        }
    }

    private func formattedDate(_ iso: String) -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        guard let date = f.date(from: iso) else { return iso }
        let out = DateFormatter(); out.dateStyle = .medium
        return out.string(from: date)
    }

    private func formattedTimestamp(_ iso: String) -> String {
        let f = ISO8601DateFormatter()
        guard let date = f.date(from: iso) else { return iso }
        let out = DateFormatter(); out.dateStyle = .medium; out.timeStyle = .short
        return out.string(from: date)
    }

    private func loadDetails() {
        let sync = SyncLinkRepository(db: db)
        reminderLink = try? sync.fetchReminderLink(itemId: row.item.id)
        calendarLink = try? sync.fetchCalendarLink(itemId: row.item.id)
        file = try? FileRepository(db: db).fetchByItemId(row.item.id)
    }
}
