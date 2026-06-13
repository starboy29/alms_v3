import SwiftUI

struct DashboardView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel: DashboardViewModel?

    var body: some View {
        Group {
            if let vm = viewModel {
                DashboardContentView(vm: vm)
            } else {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = DashboardViewModel(db: appState.db)
            } else {
                viewModel?.load()
            }
        }
        .navigationTitle("Dashboard")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    viewModel?.load()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
    }
}

private struct DashboardContentView: View {
    @Bindable var vm: DashboardViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                statsRow
                if !vm.upcomingItems.isEmpty {
                    upcomingCard
                }
                activityCard
            }
            .padding(18)
        }
        .sheet(isPresented: $vm.showSyncIssues) {
            SyncIssuesView(vm: vm)
        }
    }

    private var statsRow: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 120, maximum: 200))],
                  spacing: 12) {
            StatCard(title: "Due Today",      value: "\(vm.itemsDueToday.count)",    icon: "calendar.badge.exclamationmark", color: vm.itemsDueToday.isEmpty ? .secondary : .orange)
            StatCard(title: "Due This Week",  value: "\(vm.dueSoonItems.count)",     icon: "calendar.badge.clock",           color: vm.dueSoonItems.isEmpty ? .secondary : .blue)
            StatCard(title: "Overdue",        value: "\(vm.overdueItems.count)",     icon: "exclamationmark.circle",         color: vm.overdueItems.isEmpty ? .secondary : .red)
            StatCard(title: "Active Items",   value: "\(vm.allActiveItems.count)",   icon: "checklist",                     color: .blue)
            StatCard(title: "Upcoming (14d)", value: "\(vm.upcomingItems.count)",    icon: "clock",                         color: .purple)
            Button { vm.showSyncIssues = true } label: {
                StatCard(title: "Sync Issues", value: "\(vm.syncFailureCount)",
                         icon: "exclamationmark.icloud",
                         color: vm.syncFailureCount > 0 ? .red : .secondary)
            }
            .buttonStyle(.plain)
            .disabled(vm.syncFailureCount == 0)
        }
    }

    private var upcomingCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Upcoming Deadlines", systemImage: "pin.fill")
                .font(.headline)
                .padding(.horizontal, 2)
            VStack(spacing: 0) {
                ForEach(vm.upcomingItems.prefix(8), id: \.id) { item in
                    HStack(spacing: 12) {
                        daysUntilBadge(item.dueDate)
                        Text(item.title)
                            .font(.callout)
                            .lineLimit(1)
                        Spacer()
                        TypeBadge(type: item.type)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .contextMenu {
                        Button("Mark Complete") { vm.completeItem(item.id) }
                        if vm.hasFile(itemId: item.id) {
                            Button("Reveal in Finder") { vm.revealInFinder(itemId: item.id) }
                        }
                        Divider()
                        Button("Archive", role: .destructive) { vm.archiveItem(item.id) }
                    }
                    if item.id != vm.upcomingItems.prefix(8).last?.id {
                        Divider().padding(.leading, 14)
                    }
                }
            }
            .glassCard(cornerRadius: 10)
        }
    }

    private var activityCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Recent Activity", systemImage: "clock.fill")
                .font(.headline)
                .padding(.horizontal, 2)
            if vm.recentActivity.isEmpty {
                Text("No activity yet.")
                    .foregroundStyle(.secondary)
                    .font(.callout)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .glassCard(cornerRadius: 10)
            } else {
                VStack(spacing: 0) {
                    ForEach(vm.recentActivity.prefix(12), id: \.id) { log in
                        HStack(spacing: 12) {
                            Image(systemName: iconForEvent(log.eventType))
                                .foregroundStyle(colorForEvent(log.eventType))
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(log.details ?? log.eventType)
                                    .font(.callout)
                                    .lineLimit(1)
                                Text(log.createdAt)
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        if log.id != vm.recentActivity.prefix(12).last?.id {
                            Divider().padding(.leading, 14)
                        }
                    }
                }
                .glassCard(cornerRadius: 10)
            }
        }
    }

    private func daysUntilBadge(_ dateStr: String?) -> some View {
        let days = daysUntil(dateStr)
        let (label, color): (String, Color) = {
            guard let d = days else { return ("—", .secondary) }
            if d <= 2 { return ("\(d)d", .red) }
            if d <= 7 { return ("\(d)d", .orange) }
            return ("\(d)d", .secondary)
        }()
        return Text(label)
            .font(.caption)
            .fontWeight(.bold)
            .foregroundStyle(color)
            .frame(width: 30)
    }

    private func daysUntil(_ iso: String?) -> Int? {
        guard let iso else { return nil }
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        guard let date = f.date(from: iso) else { return nil }
        return Calendar.current.dateComponents([.day], from: Date(), to: date).day
    }

    private func iconForEvent(_ type: String) -> String {
        switch type {
        case "import":              return "arrow.down.circle.fill"
        case "error":               return "exclamationmark.triangle.fill"
        case "sync":                return "arrow.triangle.2.circlepath"
        case "routed":              return "arrow.triangle.2.circlepath"
        case "file_move":           return "folder.fill"
        case "duplicate_prevented": return "doc.on.doc.fill"
        default:                    return "circle.fill"
        }
    }

    private func colorForEvent(_ type: String) -> Color {
        switch type {
        case "import":              return .blue
        case "error":               return .red
        case "sync":                return .green
        case "routed":              return .green
        case "file_move":           return .teal
        case "duplicate_prevented": return .purple
        default:                    return .secondary
        }
    }
}

private struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .font(.system(size: 18))
            Text(value)
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundStyle(color)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(cornerRadius: 12)
    }
}
