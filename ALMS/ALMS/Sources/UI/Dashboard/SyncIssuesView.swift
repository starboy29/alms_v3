import SwiftUI

struct SyncIssuesView: View {
    @Bindable var vm: DashboardViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Label("Sync Issues", systemImage: "exclamationmark.icloud")
                    .font(.title2.weight(.semibold))
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary).font(.title3)
                }
                .buttonStyle(.plain)
            }
            .padding(20)
            Divider()
            if vm.failedSyncs.isEmpty {
                ContentUnavailableView("No sync issues", systemImage: "checkmark.icloud",
                    description: Text("All reminders and calendar events synced successfully."))
            } else {
                List(vm.failedSyncs) { failure in
                    HStack(spacing: 12) {
                        Image(systemName: failure.integration == "Reminder" ? "bell.fill" : "calendar")
                            .foregroundStyle(failure.integration == "Reminder" ? .purple : .blue)
                            .frame(width: 24)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(failure.itemTitle)
                                .font(.callout).fontWeight(.medium).lineLimit(1)
                            Text(failure.integration)
                                .font(.caption).foregroundStyle(.secondary)
                            if let err = failure.errorMessage {
                                Text(err).font(.caption).foregroundStyle(.red).lineLimit(2)
                            }
                        }
                        Spacer()
                        Button("Retry") { vm.retrySync(itemId: failure.itemId) }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                    }
                    .padding(.vertical, 4)
                }
                .listStyle(.plain)
            }
        }
        .frame(minWidth: 420, minHeight: 320)
    }
}
