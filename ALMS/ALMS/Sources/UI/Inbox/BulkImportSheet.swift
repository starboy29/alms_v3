import SwiftUI

struct BulkImportSheet: View {
    @Bindable var vm: InboxViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerBar
            Divider()
            rowList
            Divider()
            footerBar
        }
        .frame(minWidth: 560, minHeight: 400)
    }

    private var headerBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Bulk Import")
                    .font(.title2.weight(.semibold))
                Text("\(vm.bulkRows.count) files")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button { vm.dismissBulkImport(); dismiss() } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
                    .font(.title3)
            }
            .buttonStyle(.plain)
        }
        .padding(20)
    }

    private var rowList: some View {
        List {
            ForEach(vm.bulkRows) { row in
                HStack(spacing: 12) {
                    statusIcon(row.status)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(row.url.lastPathComponent)
                            .font(.callout)
                            .lineLimit(1)
                        if let err = row.errorMessage {
                            Text(err)
                                .font(.caption)
                                .foregroundStyle(row.status == .skipped ? Color.secondary : Color.red)
                        }
                    }
                    Spacer()
                    if row.status == .pending {
                        Button("File") { vm.confirmBulkRow(row) }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                    } else if row.status == .filing {
                        ProgressView().controlSize(.small)
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .listStyle(.plain)
    }

    private var footerBar: some View {
        HStack {
            let pendingCount = vm.bulkRows.filter { $0.status == .pending }.count
            let filedCount = vm.bulkRows.filter { $0.status == .filed }.count
            let skippedCount = vm.bulkRows.filter { $0.status == .skipped }.count
            Text("\(pendingCount) pending · \(filedCount) filed · \(skippedCount) skipped")
                .font(.callout)
                .foregroundStyle(.secondary)
            Spacer()
            if vm.isBulkFiling {
                ProgressView().controlSize(.small)
            }
            Button("Done") { vm.dismissBulkImport(); dismiss() }
            Button("File All") { vm.confirmAllBulk() }
                .buttonStyle(.borderedProminent)
                .disabled(vm.bulkRows.filter { $0.status == .pending }.isEmpty || vm.isBulkFiling)
        }
        .padding(16)
    }

    @ViewBuilder
    private func statusIcon(_ status: BulkRowStatus) -> some View {
        switch status {
        case .pending:
            Image(systemName: "circle").foregroundStyle(.secondary)
        case .filing:
            ProgressView().controlSize(.mini)
        case .filed:
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
        case .skipped:
            Image(systemName: "minus.circle.fill").foregroundStyle(.secondary)
        case .failed:
            Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
        }
    }
}
