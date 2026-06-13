# ALMS Feature Batch — Design Spec
**Date:** 2026-06-13

## Scope
Five features added to the existing ALMS macOS app:
1. Bulk Import
2. Smart Due Date Warnings
3. Quick Entry File Drop
4. Overdue Highlighting
5. Reveal in Finder

---

## 1. Bulk Import

### What it does
User drags a folder (or selects multiple files) onto InboxView. ALMS processes every file through the existing `InboxService.submitFile` pipeline and shows a single confirmation sheet for the whole batch.

### Components

**`BulkImportSheet`** (new view)
- Presented as a sheet over `InboxView` when a folder/multi-file drop is detected
- Shows a list of rows: filename · auto-detected subject + type · status chip (Pending / Confirmed / Filed / Skipped-Duplicate / Failed)
- "Confirm All" button files every Pending row using its auto-detected metadata
- Tapping a row opens an inline edit for that file's metadata before filing
- Progress indicator while files are being processed

**`InboxView` drop target**
- Existing `onDrop` handler extended to accept `NSFilenamesPboardType` with multiple URLs or a single directory URL
- If directory: enumerate `FileManager.default.contentsOfDirectory` (non-recursive, supported extensions only: pdf, png, jpg, jpeg, docx, txt, md)
- Passes the file list to `BulkImportSheet`

**`InboxViewModel` additions**
- `func startBulkImport(urls: [URL])` — validates each file (duplicate check), builds a `[BulkImportRow]` model, sets `showBulkImport = true`
- `func confirmBulkRow(_ row: BulkImportRow)` — calls `InboxService.submitFile` for one row, updates its status
- `func confirmAllBulk()` — iterates pending rows, calls confirm sequentially to avoid DB write conflicts

**`BulkImportRow`** (new model, in-memory only)
```swift
struct BulkImportRow: Identifiable {
    let id = UUID()
    let url: URL
    var metadata: ExtractedMetadata
    var status: BulkRowStatus  // pending, confirmed, filed, skipped, failed
    var errorMessage: String?
}
```

### Error handling
- Duplicates: status = `.skipped`, shows "Already filed" in the chip — not an error
- File not found / move failed: status = `.failed`, shows error message, user can retry individually
- If all rows fail, sheet stays open with a summary

---

## 2. Smart Due Date Warnings

### What it does
On app launch and once per week, ALMS checks for items due in the next 7 days and fires a system notification summarising them by subject. Dashboard gets a "Due This Week" stat card.

### Components

**`DueDateWarningService`** (new service)
- `func scheduleWeeklyCheck()` — registers a `UNCalendarNotificationTrigger` for Sunday 9pm that repeats weekly
- `func checkAndNotifyIfNeeded()` — called on `AppState.checkFirstLaunch()`:
  - Queries `ItemRepository` for `status = active AND dueDate BETWEEN today AND today+7`
  - Groups by subject code
  - If count > 0: fires a local notification — title: "Due this week", body: "5 items — ANN (2), CS (3)"
  - Stores `UserDefaults` timestamp so it only fires once per day even if app relaunches multiple times

**`ItemRepository` addition**
- `func fetchDueSoon(withinDays: Int) throws -> [Item]` — single SQL query with date range

**`DashboardView` addition**
- New stat card: "Due This Week" with count, tapping filters the dashboard list to those items
- Existing stat cards: total items, overdue (see feature 4)

### Notification
```
Title: Due this week
Body:  5 items — ANN (2), CS (3)
```
Tapping the notification opens ALMS main window and switches to Dashboard tab.

---

## 3. Quick Entry File Drop

### What it does
A drag-drop zone is added to the Quick Entry panel. Dropping a file runs duplicate check + shows `MetadataConfirmationSheet` inside the panel. Confirmed → filed, success toast shown, panel stays open.

### Components

**`QuickEntryView` additions**
- Drop zone below the text field: dashed border, "Drop a file here" label, accepts `NSFilenamesPboardType`
- On drop: calls `QuickEntryViewModel.handleFileDrop(url:)`
- When metadata confirmation is needed: presents `MetadataConfirmationSheet` as a sheet on the Quick Entry window

**`QuickEntryManager` / `QuickEntryViewModel` additions**
- `func handleFileDrop(url: URL)` — calls `InboxService.validateFile`, then either:
  - Auto-files if confidence is high (shows success toast)
  - Shows `MetadataConfirmationSheet` if confidence is low
- Success toast: green banner at top of Quick Entry panel, auto-dismisses after 2s

### Window sizing
Quick Entry panel grows vertically when the confirmation sheet is presented (uses `.sheet` modifier on the panel window, not a new window).

---

## 4. Overdue Highlighting

### What it does
Items past their due date (and still active) are visually distinguished in every list view. Dashboard surfaces an "Overdue" count card.

### Components

**`ItemRowView` changes**
- Computed property: `var isOverdue: Bool` — `dueDate < today && status == .active`
- When overdue:
  - Due date text colour: `.red`
  - Left border: 3pt red accent (using `.overlay(alignment: .leading)`)
  - No icon or emoji — colour alone is sufficient

**`DashboardViewModel` addition**
- `var overdueCount: Int` — derived from `fetchAll` filtered by overdue condition
- "Overdue" stat card on dashboard; tapping it sets a `filterOverdue = true` flag that filters `visibleItems`

**`InboxViewModel` / `DashboardViewModel`**
- No new DB queries needed — overdue is computed client-side from existing item list using `Date()` comparison

### Date comparison
Use `Calendar.current.startOfDay(for: Date())` for "today" so items due today are not marked overdue until midnight.

---

## 5. Reveal in Finder

### What it does
A "Reveal in Finder" context menu action appears on every item row that has a filed file. Calls the existing `FinderService.revealInFinder`.

### Components

**`ItemRowView` context menu**
```swift
.contextMenu {
    if let filePath = item.filedPath {
        Button("Reveal in Finder") {
            FinderService(db: db).revealInFinder(path: filePath)
        }
    }
}
```

**`Item` model / view model**
- `ItemRowView` needs the associated `ALMSFile.storedPath` to call `revealInFinder`
- `InboxViewModel` and `DashboardViewModel` load a `[String: String]` lookup (`itemId → storedPath`) alongside the items list using `FileRepository`

**Where it appears**
- `InboxView` item list
- `DashboardView` item list
- `ItemDetailView` sheet (as a button, not just context menu)

---

## Architecture Notes

- All new views follow the existing `@Observable` ViewModel pattern
- All new DB queries go through the existing Repository layer — no raw SQL in views or services
- `DueDateWarningService` is initialised once in `AppState.checkFirstLaunch()` — not a singleton
- No new dependencies required

## Files to Create
- `Sources/Services/DueDateWarningService.swift`
- `Sources/UI/Inbox/BulkImportSheet.swift`

## Files to Modify
- `Sources/UI/Inbox/InboxView.swift` — bulk drop, file drop wiring
- `Sources/UI/Inbox/InboxViewModel.swift` — bulk import support (BulkImportRow model + bulk confirm logic lives here)
- `Sources/UI/QuickEntry/QuickEntryView.swift` — file drop zone
- `Sources/UI/QuickEntry/QuickEntryManager.swift` — file drop handler
- `Sources/UI/Dashboard/DashboardView.swift` — stat cards, overdue filter
- `Sources/UI/Dashboard/DashboardViewModel.swift` — due-soon + overdue counts
- `Sources/UI/Components/ItemRowView.swift` — overdue highlight, context menu
- `Sources/UI/Components/ItemDetailView.swift` — Reveal in Finder button
- `Sources/Database/Repositories/ItemRepository.swift` — `fetchDueSoon`
- `Sources/UI/AppState.swift` — wire DueDateWarningService
