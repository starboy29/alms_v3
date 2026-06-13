import SwiftUI

struct ItemRowView: View {
    let item: Item
    var subjectCode: String? = nil
    var unitName: String? = nil

    private var isOverdue: Bool {
        guard item.status == ItemStatus.active.rawValue,
              let due = item.dueDate else { return false }
        let today = DateParser.iso8601Date(from: Date())
        return due < today
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            if let code = subjectCode {
                SubjectPill(code: code)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(.callout)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    TypeBadge(type: item.type)
                    if let unit = unitName {
                        Text(unit)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 4))
                    }
                    if let due = item.dueDate {
                        Text(formattedDate(due))
                            .font(.caption)
                            .foregroundStyle(isOverdue ? .red : .secondary)
                            .fontWeight(isOverdue ? .semibold : .regular)
                    }
                }
            }
            Spacer()
            statusMark
        }
        .padding(.vertical, 2)
        .overlay(alignment: .leading) {
            if isOverdue {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.red)
                    .frame(width: 3)
                    .padding(.vertical, 4)
                    .offset(x: -8)
            }
        }
    }

    private var statusMark: some View {
        Group {
            if item.status == ItemStatus.completed.rawValue {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
            } else if item.status == ItemStatus.archived.rawValue {
                Image(systemName: "archivebox").foregroundStyle(.secondary)
            } else {
                Image(systemName: "circle").foregroundStyle(Color.secondary.opacity(0.4))
            }
        }
        .font(.system(size: 16))
    }

    private func formattedDate(_ iso: String) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        guard let date = f.date(from: iso) else { return iso }
        let out = DateFormatter()
        out.dateFormat = "MMM d"
        return "Due \(out.string(from: date))"
    }
}
