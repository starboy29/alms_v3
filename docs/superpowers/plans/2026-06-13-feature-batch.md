# ALMS Feature Batch Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add overdue highlighting, dashboard stat cards, Reveal in Finder in inbox, smart due date warnings, Quick Entry file drop, and bulk import to the ALMS macOS app.

**Architecture:** All features extend existing patterns — `@Observable` ViewModels, Repository layer for DB queries, `NotificationService.send` for system notifications. No new dependencies. Tasks are ordered from simplest to most complex so each builds confidence before the next.

**Tech Stack:** Swift, SwiftUI, GRDB, UserNotifications, AppKit

---

## Task 1: Overdue Highlighting in ItemRowView

**Files:**
- Modify: `ALMS/ALMS/Sources/UI/Components/ItemRowView.swift`

- [ ] **Step 1: Add `isOverdue` computed property and red styling**

Replace the entire `ItemRowView.swift` with:

```swift
import SwiftUI

struct ItemRowView: View {
    let item: Item
    var subjectCode: String? = nil
    var unitName: String? = nil

    private var isOverdue: Bool {
        guard item.status == ItemStatus.active.rawValue,
              let due = item.dueDate else { return false }
        let today = DateParser.iso8601Date(from: Calendar.current.startOfDay(for: Date()))
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
```

- [ ] **Step 2: Build and verify**

Build in Xcode (⌘B). Create a test item with a past due date in the inbox and confirm the due date text turns red with a left red bar. Items with future due dates or no due date should look unchanged.

- [ ] **Step 3: Commit**

```bash
git add ALMS/ALMS/Sources/UI/Components/ItemRowView.swift
git commit -m "feat: highlight overdue items in red in ItemRowView"
```

---

## Task 2: Overdue + Due-This-Week Stat Cards on Dashboard

**Files:**
- Modify: `ALMS/ALMS/Sources/Database/Repositories/ItemRepository.swift`
- Modify: `ALMS/ALMS/Sources/UI/Dashboard/DashboardViewModel.swift`
- Modify: `ALMS/ALMS/Sources/UI/Dashboard/DashboardView.swift`

- [ ] **Step 1: Add `fetchDueSoon(withinDays:)` to ItemRepository**

Open `ALMS/ALMS/Sources/Database/Repositories/ItemRepository.swift` and add this method after `fetchDueBefore`:

```swift
func fetchDueSoon(withinDays days: Int) throws -> [Item] {
    let today = Calendar.current.startOfDay(for: Date())
    let cutoff = Calendar.current.date(byAdding: .day, value: days, to: today) ?? today
    let todayStr = DateParser.iso8601Date(from: today)
    let cutoffStr = DateParser.iso8601Date(from: cutoff)
    return try db.dbQueue.read { db in
        try Item
            .filter(Column("due_date") != nil)
            .filter(Column("due_date") >= todayStr)
            .filter(Column("due_date") <= cutoffStr)
            .filter(Column("status") == ItemStatus.active.rawValue)
            .order(Column("due_date"))
            .fetchAll(db)
    }
}
```

- [ ] **Step 2: Add `overdueItems` and `dueSoonItems` to DashboardViewModel**

Open `ALMS/ALMS/Sources/UI/Dashboard/DashboardViewModel.swift`.

Add `dueSoonItems: [Item] = []` to the stored properties at the top of the class (alongside `upcomingItems`, `allActiveItems`, etc.).

In `load()`, add after `allActiveItems = ...`:
```swift
dueSoonItems = (try? ItemRepository(db: db).fetchDueSoon(withinDays: 7)) ?? []
```

Add this computed property at the bottom of the class (before the closing brace):
```swift
var overdueItems: [Item] {
    let today = DateParser.iso8601Date(from: Calendar.current.startOfDay(for: Date()))
    return allActiveItems.filter { item in
        guard let due = item.dueDate else { return false }
        return due < today
    }
}
```

- [ ] **Step 3: Add stat cards to DashboardView**

Open `ALMS/ALMS/Sources/UI/Dashboard/DashboardView.swift`. Replace the `statsRow` computed property:

```swift
private var statsRow: some View {
    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()),
                        GridItem(.flexible()), GridItem(.flexible()),
                        GridItem(.flexible()), GridItem(.flexible())],
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
```

- [ ] **Step 4: Build and verify**

Build (⌘B). Open the Dashboard tab. Confirm three new stat cards appear: "Due This Week", "Overdue", and the existing ones. Add a test item with a past due date — Overdue count should increment.

- [ ] **Step 5: Commit**

```bash
git add ALMS/ALMS/Sources/Database/Repositories/ItemRepository.swift \
        ALMS/ALMS/Sources/UI/Dashboard/DashboardViewModel.swift \
        ALMS/ALMS/Sources/UI/Dashboard/DashboardView.swift
git commit -m "feat: add overdue and due-this-week stat cards to dashboard"
```

---

## Task 3: Reveal in Finder Context Menu in InboxView

**Files:**
- Modify: `ALMS/ALMS/Sources/Database/Repositories/FileRepository.swift`
- Modify: `ALMS/ALMS/Sources/UI/Inbox/InboxViewModel.swift`
- Modify: `ALMS/ALMS/Sources/UI/Inbox/InboxView.swift`

- [ ] **Step 1: Add `fetchPathMap` to FileRepository**

Open `ALMS/ALMS/Sources/Database/Repositories/FileRepository.swift`. Add after `fetchByItemId`:

```swift
func fetchPathMap(itemIds: [String]) throws -> [String: String] {
    guard !itemIds.isEmpty else { return [:] }
    return try db.dbQueue.read { db in
        let files = try ALMSFile
            .filter(itemIds.contains(Column("item_id")))
            .fetchAll(db)
        return Dictionary(uniqueKeysWithValues: files.map { ($0.itemId, $0.storedPath) })
    }
}
```

- [ ] **Step 2: Add `filePath` to InboxRow**

Open `ALMS/ALMS/Sources/UI/Inbox/InboxViewModel.swift`. Update `InboxRow`:

```swift
struct InboxRow: Identifiable {
    var id: String { item.id }
    let item: Item
    let subjectCode: String?
    let unitName: String?
    let filePath: String?
}
```

- [ ] **Step 3: Populate filePath in loadRecentItems**

In `InboxViewModel.loadRecentItems()`, replace the final `recentItems = items.map { ... }` block with:

```swift
let filePathMap = (try? FileRepository(db: db).fetchPathMap(itemIds: items.map(\.id))) ?? [:]

recentItems = items.map { item in
    InboxRow(
        item: item,
        subjectCode: subjectMap[item.subjectId],
        unitName: item.unitId.flatMap { unitMap[$0] },
        filePath: filePathMap[item.id]
    )
}
```

- [ ] **Step 4: Add context menu to InboxView list rows**

Open `ALMS/ALMS/Sources/UI/Inbox/InboxView.swift`. In the `itemsList` computed property, update the `List` contents — add `.contextMenu` after `.onTapGesture`:

```swift
List(vm.recentItems) { row in
    ItemRowView(item: row.item, subjectCode: row.subjectCode, unitName: row.unitName)
        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
        .contentShape(Rectangle())
        .onTapGesture { detailRow = row }
        .contextMenu {
            if let path = row.filePath {
                Button {
                    NSWorkspace.shared.selectFile(path, inFileViewerRootedAtPath: "")
                } label: {
                    Label("Reveal in Finder", systemImage: "folder")
                }
            }
        }
}
```

- [ ] **Step 5: Build and verify**

Build (⌘B). File a PDF through the inbox. Right-click the resulting item in the list — "Reveal in Finder" should appear. Clicking it should open Finder with the file selected. Items without files should show no context menu.

- [ ] **Step 6: Commit**

```bash
git add ALMS/ALMS/Sources/Database/Repositories/FileRepository.swift \
        ALMS/ALMS/Sources/UI/Inbox/InboxViewModel.swift \
        ALMS/ALMS/Sources/UI/Inbox/InboxView.swift
git commit -m "feat: add Reveal in Finder context menu to inbox item list"
```

---

## Task 4: Smart Due Date Warnings

**Files:**
- Create: `ALMS/ALMS/Sources/Services/DueDateWarningService.swift`
- Modify: `ALMS/ALMS/Sources/UI/AppState.swift`

- [ ] **Step 1: Create DueDateWarningService**

Create `ALMS/ALMS/Sources/Services/DueDateWarningService.swift`:

```swift
import Foundation

struct DueDateWarningService {
    private let db: ALMSDatabase
    private static let lastCheckedKey = "due_warning_last_checked_date"

    init(db: ALMSDatabase) { self.db = db }

    func checkAndNotifyIfNeeded() {
        let today = DateParser.iso8601Date(from: Date())
        guard UserDefaults.standard.string(forKey: Self.lastCheckedKey) != today else { return }

        guard let items = try? ItemRepository(db: db).fetchDueSoon(withinDays: 7),
              !items.isEmpty else { return }

        UserDefaults.standard.set(today, forKey: Self.lastCheckedKey)

        let subjectRepo = SubjectRepository(db: db)
        var countByCode: [String: Int] = [:]
        for item in items {
            let code = (try? subjectRepo.fetchById(item.subjectId))?.code ?? "?"
            countByCode[code, default: 0] += 1
        }

        let summary = countByCode
            .sorted { $0.value > $1.value }
            .prefix(4)
            .map { "\($0.key) (\($0.value))" }
            .joined(separator: ", ")

        NotificationService.send(
            title: "Due this week",
            body: "\(items.count) item\(items.count == 1 ? "" : "s") — \(summary)"
        )
    }
}
```

- [ ] **Step 2: Wire into AppState.checkFirstLaunch()**

Open `ALMS/ALMS/Sources/UI/AppState.swift`. Add a call inside `checkFirstLaunch()` after `NotificationService.requestPermission()`:

```swift
func checkFirstLaunch() {
    Task { await RemindersService.requestAccess() }
    Task { await CalendarService.requestAccess() }
    reindexSpotlightIfNeeded()
    NotificationService.requestPermission()
    DueDateWarningService(db: db).checkAndNotifyIfNeeded()
}
```

- [ ] **Step 3: Build and verify**

Build (⌘B). To test: add an item with a due date within the next 7 days. Clear the UserDefaults key `due_warning_last_checked_date` in the debugger or by deleting app data. Relaunch — a system notification should appear saying "Due this week: 1 item — <subject code> (1)".

- [ ] **Step 4: Commit**

```bash
git add ALMS/ALMS/Sources/Services/DueDateWarningService.swift \
        ALMS/ALMS/Sources/UI/AppState.swift
git commit -m "feat: add smart due date warning notification on launch"
```

---

## Task 5: Quick Entry File Drop

**Files:**
- Modify: `ALMS/ALMS/Sources/UI/AppState.swift`
- Modify: `ALMS/ALMS/Sources/UI/QuickEntry/QuickEntryView.swift`
- Modify: `ALMS/ALMS/Sources/UI/QuickEntry/QuickEntryManager.swift`
- Modify: `ALMS/ALMS/Sources/UI/Inbox/InboxView.swift`

- [ ] **Step 1: Add `quickEntryPendingFilePath` to AppState**

Open `ALMS/ALMS/Sources/UI/AppState.swift`. Add alongside `quickEntryPendingText`:

```swift
@Observable
final class AppState {
    var selectedTab: AppTab = .inbox
    var quickEntryPendingText: String?
    var quickEntryPendingFilePath: String?   // ← add this line
    let db: ALMSDatabase = .shared
    // ... rest unchanged
}
```

- [ ] **Step 2: Update QuickEntryView to include a drop zone**

Replace the entire `ALMS/ALMS/Sources/UI/QuickEntry/QuickEntryView.swift`:

```swift
import SwiftUI
import UniformTypeIdentifiers

extension Notification.Name {
    static let quickEntryNeedsConfirmation = Notification.Name("com.alms.quickEntryNeedsConfirmation")
    static let quickEntryFilePending = Notification.Name("com.alms.quickEntryFilePending")
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
```

- [ ] **Step 3: Resize the QuickEntry window to 520×120**

Open `ALMS/ALMS/Sources/UI/QuickEntry/QuickEntryManager.swift`. Update the two size references in `buildWindow()`:

```swift
private func buildWindow() {
    let view = QuickEntryView(db: db) { [weak self] in
        DispatchQueue.main.async { self?.hide() }
    }
    let hosting = NSHostingView(rootView: view)
    hosting.frame = NSRect(x: 0, y: 0, width: 520, height: 120)  // ← 68 → 120

    let w = QuickEntryWindow(
        contentRect: NSRect(x: 0, y: 0, width: 520, height: 120), // ← 68 → 120
        styleMask: [.borderless, .fullSizeContentView],
        backing: .buffered,
        defer: false
    )
    w.level = .floating
    w.isOpaque = false
    w.backgroundColor = .clear
    w.hasShadow = true
    w.contentView = hosting
    w.isReleasedWhenClosed = false
    w.delegate = self
    self.window = w
}
```

- [ ] **Step 4: Route quickEntryFilePending notification through AppState into InboxView**

Open `ALMS/ALMS/Sources/UI/AppState.swift`. Add an observer for the file notification in `checkFirstLaunch()`:

```swift
func checkFirstLaunch() {
    Task { await RemindersService.requestAccess() }
    Task { await CalendarService.requestAccess() }
    reindexSpotlightIfNeeded()
    NotificationService.requestPermission()
    DueDateWarningService(db: db).checkAndNotifyIfNeeded()
    observeQuickEntryFile()
}

private func observeQuickEntryFile() {
    NotificationCenter.default.addObserver(
        forName: .quickEntryFilePending,
        object: nil,
        queue: .main
    ) { [weak self] note in
        self?.selectedTab = .inbox
        self?.quickEntryPendingFilePath = note.object as? String
    }
}
```

- [ ] **Step 5: Handle `quickEntryPendingFilePath` in InboxView**

Open `ALMS/ALMS/Sources/UI/Inbox/InboxView.swift`. In the outer `InboxView` body, add an `onChange` handler alongside the existing `quickEntryPendingText` handler:

```swift
.onChange(of: appState.quickEntryPendingFilePath) { _, newValue in
    if let path = newValue {
        viewModel?.handleDroppedFile(at: path)
        appState.quickEntryPendingFilePath = nil
    }
}
```

Also add it inside the `onAppear` block (after the quickEntryPendingText check):
```swift
.onAppear {
    if viewModel == nil {
        viewModel = InboxViewModel(db: appState.db)
    }
    if let text = appState.quickEntryPendingText {
        viewModel?.inputText = text
        appState.quickEntryPendingText = nil
    }
    if let path = appState.quickEntryPendingFilePath {  // ← add
        viewModel?.handleDroppedFile(at: path)
        appState.quickEntryPendingFilePath = nil
    }
}
```

- [ ] **Step 6: Build and verify**

Build (⌘B). Press Control+Option+Space to open the Quick Entry panel. Confirm it's taller (120px) with a "Drop a file" strip at the bottom. Drop a PDF onto the drop strip — panel should dismiss and InboxView should open the FileDescriptionSheet for that file.

- [ ] **Step 7: Commit**

```bash
git add ALMS/ALMS/Sources/UI/AppState.swift \
        ALMS/ALMS/Sources/UI/QuickEntry/QuickEntryView.swift \
        ALMS/ALMS/Sources/UI/QuickEntry/QuickEntryManager.swift \
        ALMS/ALMS/Sources/UI/Inbox/InboxView.swift
git commit -m "feat: add file drop to Quick Entry panel"
```

---

## Task 6: Bulk Import

**Files:**
- Modify: `ALMS/ALMS/Sources/UI/Inbox/InboxViewModel.swift`
- Create: `ALMS/ALMS/Sources/UI/Inbox/BulkImportSheet.swift`
- Modify: `ALMS/ALMS/Sources/UI/Inbox/InboxView.swift`

- [ ] **Step 1: Add BulkImportRow model and bulk state to InboxViewModel**

Open `ALMS/ALMS/Sources/UI/Inbox/InboxViewModel.swift`. Add the model and new state properties.

Add the model at the top of the file, after `InboxRow`:

```swift
enum BulkRowStatus { case pending, filing, filed, skipped, failed }

struct BulkImportRow: Identifiable {
    let id = UUID()
    let url: URL
    var status: BulkRowStatus = .pending
    var errorMessage: String?
}
```

In `InboxViewModel`, add new state properties alongside the existing ones:

```swift
var bulkRows: [BulkImportRow] = []
var showBulkImport = false
var isBulkFiling = false
```

- [ ] **Step 2: Add bulk import methods to InboxViewModel**

Add these methods to `InboxViewModel` before the `// MARK: - Private` line:

```swift
func startBulkImport(urls: [URL]) {
    bulkRows = urls.map { BulkImportRow(url: $0) }
    showBulkImport = true
}

func confirmBulkRow(_ row: BulkImportRow) {
    guard let idx = bulkRows.firstIndex(where: { $0.id == row.id }) else { return }
    bulkRows[idx].status = .filing
    Task { @MainActor in
        do {
            let result = try await service.submitFile(row.url.path)
            if result.needsConfirmation {
                bulkRows[idx].status = .failed
                bulkRows[idx].errorMessage = "Could not detect subject — file individually"
            } else {
                bulkRows[idx].status = .filed
                loadRecentItems()
            }
        } catch InboxError.duplicateFile {
            bulkRows[idx].status = .skipped
            bulkRows[idx].errorMessage = "Already filed"
        } catch {
            bulkRows[idx].status = .failed
            bulkRows[idx].errorMessage = error.localizedDescription
        }
    }
}

func confirmAllBulk() {
    let pending = bulkRows.indices.filter { bulkRows[$0].status == .pending }
    guard !pending.isEmpty else { return }
    isBulkFiling = true
    Task { @MainActor in
        defer { isBulkFiling = false }
        for idx in pending {
            bulkRows[idx].status = .filing
            do {
                let result = try await service.submitFile(bulkRows[idx].url.path)
                if result.needsConfirmation {
                    bulkRows[idx].status = .failed
                    bulkRows[idx].errorMessage = "Could not detect subject — file individually"
                } else {
                    bulkRows[idx].status = .filed
                }
            } catch InboxError.duplicateFile {
                bulkRows[idx].status = .skipped
                bulkRows[idx].errorMessage = "Already filed"
            } catch {
                bulkRows[idx].status = .failed
                bulkRows[idx].errorMessage = error.localizedDescription
            }
        }
        loadRecentItems()
    }
}

func dismissBulkImport() {
    showBulkImport = false
    bulkRows = []
}
```

- [ ] **Step 3: Create BulkImportSheet**

Create `ALMS/ALMS/Sources/UI/Inbox/BulkImportSheet.swift`:

```swift
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
        List(vm.bulkRows) { row in
            HStack(spacing: 12) {
                statusIcon(row.status)
                VStack(alignment: .leading, spacing: 2) {
                    Text(row.url.lastPathComponent)
                        .font(.callout)
                        .lineLimit(1)
                    if let err = row.errorMessage {
                        Text(err)
                            .font(.caption)
                            .foregroundStyle(row.status == .skipped ? .secondary : .red)
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
```

- [ ] **Step 4: Update InboxView drop zone to detect folders and multiple files**

Open `ALMS/ALMS/Sources/UI/Inbox/InboxView.swift`.

First, add the `BulkImportSheet` sheet to `InboxContentView.body`. Add it after the existing `.sheet(isPresented: $vm.showFileDescription ...)` block:

```swift
.sheet(isPresented: $vm.showBulkImport, onDismiss: { vm.dismissBulkImport() }) {
    BulkImportSheet(vm: vm)
}
```

Next, replace the `dropZone` computed property's `.onDrop` modifier (the last ~10 lines of `dropZone`):

```swift
.onDrop(of: [.fileURL], isTargeted: $vm.isDragTargeted) { providers in
    var urls: [URL] = []
    let group = DispatchGroup()
    for provider in providers {
        group.enter()
        _ = provider.loadDataRepresentation(forTypeIdentifier: UTType.fileURL.identifier) { data, _ in
            defer { group.leave() }
            guard let data,
                  let str = String(data: data, encoding: .utf8),
                  let url = URL(string: str) else { return }
            urls.append(url)
        }
    }
    group.notify(queue: .main) {
        let supported = Set(["pdf","png","jpg","jpeg","docx","pptx","xlsx","txt","md","zip"])
        let expanded: [URL] = urls.flatMap { url -> [URL] in
            var isDir: ObjCBool = false
            FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)
            if isDir.boolValue {
                let contents = (try? FileManager.default.contentsOfDirectory(
                    at: url, includingPropertiesForKeys: nil,
                    options: .skipsHiddenFiles
                )) ?? []
                return contents.filter { supported.contains($0.pathExtension.lowercased()) }
            }
            return [url]
        }
        if expanded.count > 1 {
            vm.startBulkImport(urls: expanded)
        } else if let single = expanded.first {
            vm.handleDroppedFile(at: single.path)
        }
    }
    return true
}
```

Also update `openFilePicker` in `InboxViewModel` to support multiple files and folders. Replace the existing `openFilePicker` method:

```swift
func openFilePicker() {
    let panel = NSOpenPanel()
    panel.allowsMultipleSelection = true
    panel.canChooseDirectories = true
    panel.canChooseFiles = true
    panel.allowedContentTypes = [.pdf, .presentation, .spreadsheet, .text,
                                 .image, .zip, .data]
    panel.title = "Choose files or a folder to import"
    guard panel.runModal() == .OK else { return }

    let supported = Set(["pdf","png","jpg","jpeg","docx","pptx","xlsx","txt","md","zip"])
    let expanded: [URL] = panel.urls.flatMap { url -> [URL] in
        var isDir: ObjCBool = false
        FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)
        if isDir.boolValue {
            let contents = (try? FileManager.default.contentsOfDirectory(
                at: url, includingPropertiesForKeys: nil,
                options: .skipsHiddenFiles
            )) ?? []
            return contents.filter { supported.contains($0.pathExtension.lowercased()) }
        }
        return [url]
    }

    if expanded.count > 1 {
        startBulkImport(urls: expanded)
    } else if let single = expanded.first {
        handleDroppedFile(at: single.path)
    }
}
```

- [ ] **Step 5: Build and verify**

Build (⌘B). Test three paths:
1. Drop a single file → existing `FileDescriptionSheet` opens (unchanged behaviour)
2. Drop a folder with multiple supported files → `BulkImportSheet` opens listing all files; "File All" processes them; status chips update in real-time
3. Click "Choose File…" → panel now allows folder selection and multi-select; selecting multiple files opens `BulkImportSheet`

- [ ] **Step 6: Commit**

```bash
git add ALMS/ALMS/Sources/UI/Inbox/InboxViewModel.swift \
        ALMS/ALMS/Sources/UI/Inbox/BulkImportSheet.swift \
        ALMS/ALMS/Sources/UI/Inbox/InboxView.swift
git commit -m "feat: add bulk import — drop a folder or multi-select to file many files at once"
```
