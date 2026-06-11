import SwiftUI

extension Notification.Name {
    static let quickEntryNeedsConfirmation = Notification.Name("com.alms.quickEntryNeedsConfirmation")
}

struct QuickEntryView: View {
    let db: ALMSDatabase
    let onDismiss: () -> Void

    @State private var text = ""
    @State private var status: EntryStatus = .idle
    @FocusState private var focused: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.3), radius: 24, x: 0, y: 10)

            HStack(spacing: 14) {
                Image(systemName: status.iconName)
                    .foregroundStyle(status.iconColor)
                    .font(.system(size: 20, weight: .medium))
                    .animation(.easeInOut(duration: 0.15), value: status.iconName)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    TextField("Add to ALMS…", text: $text)
                        .textFieldStyle(.plain)
                        .font(.system(size: 16))
                        .focused($focused)
                        .disabled(status.isProcessing)
                        .onSubmit { submit() }

                    Text(status.hint)
                        .font(.system(size: 11))
                        .foregroundStyle(status.hintColor)
                        .animation(.easeInOut(duration: 0.15), value: status.hint)
                }

                if status.isProcessing {
                    ProgressView().controlSize(.small)
                }
            }
            .padding(.horizontal, 18)
        }
        .frame(width: 520, height: 68)
        .onAppear {
            text = ""
            status = .idle
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { focused = true }
        }
        .onKeyPress(.escape) { onDismiss(); return .handled }
    }

    private func submit() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { onDismiss(); return }

        status = .processing
        do {
            let result = try InboxService(db: db).submitText(trimmed)
            if result.needsConfirmation {
                NotificationCenter.default.post(
                    name: .quickEntryNeedsConfirmation,
                    object: trimmed
                )
                onDismiss()
            } else {
                text = ""
                status = .success
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { onDismiss() }
            }
        } catch {
            status = .error(error.localizedDescription)
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                status = .idle
            }
        }
    }
}

enum EntryStatus {
    case idle, processing, success, error(String)

    var isProcessing: Bool {
        if case .processing = self { return true }
        return false
    }

    var iconName: String {
        switch self {
        case .success: return "checkmark.circle.fill"
        case .error:   return "exclamationmark.circle.fill"
        default:       return "plus.circle.fill"
        }
    }

    var iconColor: Color {
        switch self {
        case .success: return .green
        case .error:   return .red
        default:       return .accentColor
        }
    }

    var hint: String {
        switch self {
        case .idle:           return "↩ to add  ·  esc to close"
        case .processing:     return "Adding…"
        case .success:        return "Added!"
        case .error(let msg): return msg
        }
    }

    var hintColor: Color {
        switch self {
        case .error:   return .red
        case .success: return .green
        default:       return .secondary
        }
    }
}
