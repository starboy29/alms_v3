import SwiftUI

struct SetupWizardView: View {
    let db: ALMSDatabase
    let onDismiss: () -> Void

    @State private var vm: SetupWizardViewModel?

    var body: some View {
        Group {
            if let vm {
                SetupWizardContentView(vm: vm, onDismiss: onDismiss)
            } else {
                ProgressView().frame(width: 580, height: 480)
            }
        }
        .onAppear {
            if vm == nil { vm = SetupWizardViewModel(db: db) }
        }
    }
}

// MARK: - Content

private struct SetupWizardContentView: View {
    @Bindable var vm: SetupWizardViewModel
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            shortcutsList
            Divider()
            footer
        }
        .frame(width: 580)
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 14) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(.yellow)
                    .frame(width: 52, height: 52)
                    .background(.yellow.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 3) {
                    Text("ALMS Setup")
                        .font(.title2).bold()
                    Text("Install the Apple Shortcut so ALMS can create calendar events automatically. (Reminders and file organization are handled natively — no shortcut needed.)")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            progressRow
        }
        .padding(20)
    }

    private var progressRow: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text("\(vm.criticalInstalled) of \(vm.criticalCount) required shortcuts installed")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(vm.totalInstalled)/\(vm.shortcuts.count) total")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.secondary.opacity(0.12))
                        .frame(height: 6)
                    Capsule()
                        .fill(vm.allCriticalDone ? Color.green : Color.accentColor)
                        .frame(
                            width: geo.size.width * CGFloat(vm.criticalInstalled) / CGFloat(max(vm.criticalCount, 1)),
                            height: 6
                        )
                        .animation(.spring(duration: 0.3), value: vm.criticalInstalled)
                }
            }
            .frame(height: 6)
        }
    }

    // MARK: Shortcuts list

    private var shortcutsList: some View {
        ScrollView {
            LazyVStack(spacing: 0, pinnedViews: .sectionHeaders) {
                let critical = vm.shortcuts.filter { $0.isCritical }
                let optional = vm.shortcuts.filter { !$0.isCritical }

                Section {
                    ForEach(critical) { s in
                        ShortcutRow(
                            status: s,
                            isExpanded: vm.expandedShortcut == s.name
                        ) { vm.toggleExpanded(s.name) }
                        if s.id != critical.last?.id { Divider().padding(.leading, 52) }
                    }
                } header: {
                    sectionLabel("Required — needed for routing", count: critical.filter { $0.isInstalled }.count, total: critical.count)
                }

                if !optional.isEmpty {
                    Section {
                        ForEach(optional) { s in
                            ShortcutRow(
                                status: s,
                                isExpanded: vm.expandedShortcut == s.name
                            ) { vm.toggleExpanded(s.name) }
                            if s.id != optional.last?.id { Divider().padding(.leading, 52) }
                        }
                    } header: {
                        sectionLabel("Optional — update & retry flows", count: optional.filter { $0.isInstalled }.count, total: optional.count)
                    }
                }
            }
        }
        .frame(maxHeight: 360)
    }

    private func sectionLabel(_ text: String, count: Int, total: Int) -> some View {
        HStack {
            Text(text.uppercased())
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
            Spacer()
            Text("\(count)/\(total)")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 7)
        .background(.regularMaterial)
    }

    // MARK: Footer

    private var footer: some View {
        VStack(spacing: 8) {
            if let msg = vm.autoInstallMessage {
                HStack(spacing: 6) {
                    if vm.isAutoInstalling {
                        ProgressView().controlSize(.small)
                    }
                    Text(msg)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.top, 4)
            }

            if let cmd = vm.terminalCommand {
                terminalPanel(cmd: cmd)
            }

            HStack(spacing: 10) {
                Button {
                    vm.autoInstall()
                } label: {
                    if vm.isAutoInstalling {
                        Label("Preparing…", systemImage: "arrow.down.circle")
                    } else {
                        Label("Install via Terminal", systemImage: "bolt.fill")
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.indigo)
                .disabled(vm.isAutoInstalling)
                .help("Generates the shortcuts and signs them in Terminal (macOS requires signing, which a sandboxed app can't do itself).")

                Button {
                    vm.verify()
                } label: {
                    if vm.isVerifying {
                        ProgressView().controlSize(.small)
                    } else {
                        Text("Verify Now")
                    }
                }
                .buttonStyle(.bordered)
                .disabled(vm.isVerifying || vm.isAutoInstalling)

                Spacer()

                if !vm.allCriticalDone {
                    Button("Skip for Now") {
                        onDismiss()
                    }
                    .foregroundStyle(.secondary)
                    .buttonStyle(.plain)
                }

                Button(vm.allCriticalDone ? "Done — Start Using ALMS" : "Continue Anyway") {
                    vm.markSetupComplete()
                    onDismiss()
                }
                .buttonStyle(.borderedProminent)
                .tint(vm.allCriticalDone ? .green : .accentColor)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
    }

    private func terminalPanel(cmd: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Run this command in Terminal", systemImage: "terminal")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                Text(cmd)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .truncationMode(.middle)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Button {
                    vm.copyTerminalCommand()
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(10)
            .background(Color.black.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))

            Text("Terminal is already open — paste with ⌘V and press Return. Shortcuts will install silently. Then tap Verify Now above.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 4)
    }
}

// MARK: - ShortcutRow

private struct ShortcutRow: View {
    let status: ShortcutStatus
    let isExpanded: Bool
    let onTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: onTap) {
                HStack(spacing: 12) {
                    statusIcon
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text(status.name)
                                .font(.callout)
                                .fontWeight(.medium)
                                .foregroundStyle(.primary)
                            if status.isCritical {
                                Text("REQUIRED")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 1)
                                    .background(.orange.opacity(0.14))
                                    .foregroundStyle(.orange)
                                    .clipShape(Capsule())
                            }
                        }
                        Text(status.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    appBadge
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                instructionPanel
                    .padding(.horizontal, 16)
                    .padding(.bottom, 14)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.easeInOut(duration: 0.18), value: isExpanded)
    }

    private var statusIcon: some View {
        ZStack {
            Circle()
                .fill(status.isInstalled ? Color.green.opacity(0.12) : Color.secondary.opacity(0.09))
                .frame(width: 34, height: 34)
            Image(systemName: status.isInstalled ? "checkmark" : "plus")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(status.isInstalled ? .green : .secondary)
        }
    }

    private var appBadge: some View {
        Text(status.appleApp)
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.secondary.opacity(0.08))
            .foregroundStyle(.secondary)
            .clipShape(Capsule())
    }

    private var instructionPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("How to create this shortcut", systemImage: "list.number")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 7) {
                ForEach(Array(steps(for: status.name).enumerated()), id: \.offset) { i, step in
                    HStack(alignment: .top, spacing: 8) {
                        Text("\(i + 1)")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                            .frame(width: 18, height: 18)
                            .background(Color.accentColor, in: Circle())
                        Text(step)
                            .font(.caption)
                            .foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .padding(12)
        .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
    }

    private func steps(for name: String) -> [String] {
        switch name {
        case "ALMS-CreateReminder":
            return [
                "Open the Shortcuts app (⌘Space → Shortcuts) and press ⌘N.",
                "Click the name field at the top and type exactly: ALMS-CreateReminder",
                "In the search panel, find and add \"Receive Input\" — set the input type to Dictionary.",
                "Add \"Get Dictionary Value\" — set Key to title; tap the variable chip next to \"from\" and choose Shortcut Input.",
                "Add another \"Get Dictionary Value\" — Key: list.",
                "Add another \"Get Dictionary Value\" — Key: due_date.",
                "Add another \"Get Dictionary Value\" — Key: notes.",
                "Add \"Combine Date and Time\" — for the Date field use the due_date variable.",
                "Add \"Add New Reminder\" — set Title to title variable, Due Date to the combined date, List to list variable, Notes to notes variable.",
                "Press ⌘S to save.",
            ]
        case "ALMS-CreateCalendarEvent":
            return [
                "Open Shortcuts and press ⌘N. Name it exactly: ALMS-CreateCalendarEvent",
                "Add \"Receive Input\" — set type to Dictionary.",
                "Add \"Get Dictionary Value\" — Key: title.",
                "Add \"Get Dictionary Value\" — Key: start_date.",
                "Add \"Get Dictionary Value\" — Key: calendar.",
                "Add \"Get Dictionary Value\" — Key: notes.",
                "Add \"Add New Event\" — Title: title variable, Start Date: start_date variable, Calendar: calendar variable, Notes: notes variable. Toggle \"All Day\" on.",
                "Press ⌘S to save.",
            ]
        default:
            return ["Open Shortcuts and create a shortcut named exactly: \(name)"]
        }
    }
}
