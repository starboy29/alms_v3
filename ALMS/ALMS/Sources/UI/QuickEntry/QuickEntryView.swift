import SwiftUI
import UniformTypeIdentifiers

extension Notification.Name {
    static let quickEntryNeedsConfirmation = Notification.Name("com.alms.quickEntryNeedsConfirmation")
}

struct QuickEntryView: View {
    let db: ALMSDatabase
    let onDismiss: () -> Void

    @State private var text = ""
    @State private var status: EntryStatus = .idle
    @State private var isFileTargeted = false
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 0) {
            textRow
            Divider().opacity(0.4)
            fileDropRow
        }
        .frame(width: 520, height: 120)
        .glassPanel(cornerRadius: 14)
        .onAppear {
            text = ""
            status = .idle
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { focused = true }
        }
        .onKeyPress(.escape) { onDismiss(); return .handled }
    }

    private var textRow: some View {
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
        .frame(height: 68)
    }

    private var fileDropRow: some View {
        HStack(spacing: 8) {
            Image(systemName: "arrow.down.doc")
                .foregroundStyle(isFileTargeted ? Color.accentColor : Color.secondary)
                .font(.system(size: 13))
            Text("Drop a file to add it")
                .font(.system(size: 12))
                .foregroundStyle(isFileTargeted ? Color.accentColor : Color.secondary)
        }
        .frame(height: 40)
        .frame(maxWidth: .infinity)
        .background(isFileTargeted ? Color.accentColor.opacity(0.08) : Color.clear)
        .animation(.easeInOut(duration: 0.1), value: isFileTargeted)
        .onDrop(of: [.fileURL], isTargeted: $isFileTargeted) { providers in
            guard let provider = providers.first else { return false }
            _ = provider.loadDataRepresentation(forTypeIdentifier: UTType.fileURL.identifier) { data, _ in
                guard let data,
                      let str = String(data: data, encoding: .utf8),
                      let url = URL(string: str) else { return }
                DispatchQueue.main.async {
                    NotificationCenter.default.post(
                        name: .quickEntryFilePending,
                        object: url.path
                    )
                    onDismiss()
                }
            }
            return true
        }
    }

    private func submit() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { onDismiss(); return }

        status = .processing
        Task { @MainActor in
            do {
                let result = try await InboxService(db: db).submitText(trimmed)
                if result.needsConfirmation {
                    NotificationCenter.default.post(
                        name: .quickEntryNeedsConfirmation,
                        object: trimmed
                    )
                    onDismiss()
                } else {
                    text = ""
                    status = .success
                    try? await Task.sleep(for: .milliseconds(700))
                    onDismiss()
                }
            } catch {
                status = .error(error.localizedDescription)
                try? await Task.sleep(for: .milliseconds(2500))
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
