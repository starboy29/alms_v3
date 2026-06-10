# ALMS - Internal API Specification

## Overview

ALMS does not expose an HTTP server. This spec defines the **internal module interface** — the contracts between modules that allow agents to build independently and plug together.

If the technology stack uses Electron or Tauri, these become IPC channel definitions. If native Swift, these become Swift module protocols.

---

## Conventions

### Return Type

Every function returns a Result envelope:

```typescript
type Result<T> = {
  success: boolean;
  data?: T;
  error?: string;
  errorCode?: ErrorCode;
}

enum ErrorCode {
  DUPLICATE_FOUND     = "DUPLICATE_FOUND",
  FILE_NOT_FOUND      = "FILE_NOT_FOUND",
  HASH_COLLISION      = "HASH_COLLISION",
  SHORTCUT_FAILED     = "SHORTCUT_FAILED",
  SHORTCUT_NOT_FOUND  = "SHORTCUT_NOT_FOUND",
  DB_ERROR            = "DB_ERROR",
  METADATA_INCOMPLETE = "METADATA_INCOMPLETE",
  PERMISSION_DENIED   = "PERMISSION_DENIED",
}
```

### ID Format

All IDs are UUID v4 strings.

### Date Format

All dates: ISO 8601 strings — `"2025-06-20"` for dates, `"2025-06-20T14:30:00Z"` for timestamps.

---

## Module: Inbox

Entry point for all input.

### `inbox.submitText(text: string) → Result<InboxSubmission>`

Accepts a raw text string.

```typescript
type InboxSubmission = {
  item_id: string;          // Created item ID
  metadata: ExtractedMetadata;
  needs_confirmation: boolean;  // true if metadata is uncertain
}
```

Behavior:
1. Extract metadata via MetadataEngine
2. If confidence < threshold: return `needs_confirmation: true`, do not write to DB yet
3. If confidence high: write to DB, trigger routing

---

### `inbox.submitFile(filePath: string) → Result<InboxSubmission>`

Accepts absolute path to a local file.

Behavior:
1. Compute SHA256 hash
2. Check DuplicateGuard.checkFile(hash)
3. If duplicate: return `DUPLICATE_FOUND` with duplicate info
4. Extract metadata
5. If uncertain: prompt user
6. On confirmation: move file, write to DB

---

### `inbox.confirmMetadata(pendingId: string, metadata: ConfirmedMetadata) → Result<InboxSubmission>`

Finalizes a submission that required user confirmation.

```typescript
type ConfirmedMetadata = {
  subject_id: string;
  unit_id?: string;
  category_id?: string;
  type: ItemType;
  title: string;
  due_date?: string;
  priority?: Priority;
  tags?: string[];
}
```

---

## Module: Metadata Engine

### `metadata.extractFromText(text: string) → Result<ExtractedMetadata>`

```typescript
type ExtractedMetadata = {
  subject?: string;      // Detected subject code or name
  subject_id?: string;   // Matched subject ID from DB
  unit?: string;
  unit_id?: string;
  type?: ItemType;
  title?: string;
  due_date?: string;
  priority?: Priority;
  tags?: string[];
  confidence: "high" | "medium" | "low";
  unmatched_fields: string[];  // Fields that could not be extracted
}
```

### `metadata.extractFromFile(filePath: string) → Result<ExtractedMetadata>`

Extracts metadata from filename, file extension, and (Phase 3) file content.

### `metadata.resolveSubject(input: string) → Result<Subject | null>`

Matches input string to a known subject by code or name. Returns null if no match.

### `metadata.resolveDate(input: string) → Result<string | null>`

Converts relative date expressions ("next Friday", "June 20") to ISO 8601. Returns null if not a date.

---

## Module: Items

### `items.create(data: ItemCreate) → Result<Item>`

```typescript
type ItemCreate = {
  subject_id: string;       // REQUIRED
  unit_id?: string;
  category_id?: string;
  type: ItemType;           // REQUIRED
  title: string;            // REQUIRED
  description?: string;
  due_date?: string;
  due_time?: string;
  priority?: Priority;
  source?: string;
  tags?: string[];
}
```

### `items.update(id: string, data: Partial<ItemCreate>) → Result<Item>`

### `items.getById(id: string) → Result<Item>`

### `items.list(filter: ItemFilter) → Result<Item[]>`

```typescript
type ItemFilter = {
  subject_id?: string;
  unit_id?: string;
  category_id?: string;
  type?: ItemType | ItemType[];
  status?: ItemStatus;
  due_before?: string;      // ISO date
  due_after?: string;
  tags?: string[];
  limit?: number;
  offset?: number;
}
```

### `items.delete(id: string) → Result<void>`

Soft delete only — sets `status = archived`. Hard delete requires explicit flag.

### `items.complete(id: string) → Result<void>`

Sets `status = completed`. Triggers completion sync to Reminders.

---

## Module: Files

### `files.import(sourcePath: string, itemId: string) → Result<File>`

Full import pipeline: hash → dedup check → move → register.

### `files.getHash(filePath: string) → Result<string>`

Returns SHA256 hash of file at path.

### `files.checkDuplicate(hash: string) → Result<DuplicateCheckResult>`

```typescript
type DuplicateCheckResult = {
  is_duplicate: boolean;
  existing_file?: File;     // Present if is_duplicate = true
  options: ("skip" | "replace" | "update_metadata")[];
}
```

### `files.reveal(fileId: string) → Result<void>`

Opens Finder and highlights the file. Calls ALMS-RevealInFinder shortcut.

### `files.verifyExists(fileId: string) → Result<boolean>`

Checks if the stored_path still contains the file. Updates `finder_verified` flag.

---

## Module: Duplicate Guard

### `duplicates.checkFile(hash: string) → Result<DuplicateCheckResult>`

### `duplicates.checkReminder(params: ReminderDedupeParams) → Result<DuplicateCheckResult>`

```typescript
type ReminderDedupeParams = {
  subject_id: string;
  title: string;
  due_date?: string;
  list_name: string;
}
```

### `duplicates.checkCalendarEvent(params: CalendarDedupeParams) → Result<DuplicateCheckResult>`

```typescript
type CalendarDedupeParams = {
  title: string;
  event_date: string;
  subject_id?: string;
}
```

### `duplicates.checkNote(params: NoteDedupeParams) → Result<DuplicateCheckResult>`

```typescript
type NoteDedupeParams = {
  title: string;
  folder_name: string;
}
```

---

## Module: Routing Engine

### `routing.route(itemId: string) → Result<RoutingPlan>`

Determines which Apple apps to update.

```typescript
type RoutingPlan = {
  item_id: string;
  targets: RoutingTarget[];
}

type RoutingTarget = {
  app: "reminders" | "calendar" | "notes" | "finder";
  action: "create" | "update" | "skip";
  reason: string;
}
```

### `routing.execute(plan: RoutingPlan) → Result<RoutingResult>`

Executes a routing plan. Calls Shortcuts Bridge for each target.

### `routing.retryFailed(itemId: string) → Result<RoutingResult>`

Retries all `failed` sync links for an item.

---

## Module: Shortcuts Bridge

### `shortcuts.call(shortcutName: string, params: Record<string, unknown>) → Result<ShortcutResponse>`

Low-level invocation.

```typescript
type ShortcutResponse = {
  output?: string;  // Raw stdout from shortcut
  parsed?: Record<string, unknown>;  // If shortcut returns JSON
}
```

### `shortcuts.verifyInstalled(name: string) → Result<boolean>`

Checks whether a named shortcut exists on the system.

### `shortcuts.verifyAll() → Result<ShortcutVerificationReport>`

Checks all required ALMS shortcuts. Used in setup wizard.

### `shortcuts.createReminder(params: ReminderParams) → Result<ShortcutResponse>`

```typescript
type ReminderParams = {
  title: string;
  notes?: string;
  due_date?: string;     // ISO 8601
  due_time?: string;
  list: string;
  priority?: "low" | "medium" | "high";
  tags?: string[];
}
```

### `shortcuts.updateReminder(params: ReminderUpdateParams) → Result<ShortcutResponse>`

```typescript
type ReminderUpdateParams = {
  reminder_ext_id?: string;  // Use if available
  match_title?: string;      // Fallback: match by title
  match_list?: string;
  new_title?: string;
  new_due_date?: string;
  new_notes?: string;
}
```

### `shortcuts.completeReminder(params: ReminderCompleteParams) → Result<ShortcutResponse>`

### `shortcuts.createCalendarEvent(params: CalendarEventParams) → Result<ShortcutResponse>`

```typescript
type CalendarEventParams = {
  title: string;
  start_date: string;
  end_date?: string;
  all_day: boolean;
  calendar: string;
  notes?: string;
}
```

### `shortcuts.updateCalendarEvent(params: CalendarEventUpdateParams) → Result<ShortcutResponse>`

### `shortcuts.createNote(params: NoteParams) → Result<ShortcutResponse>`

```typescript
type NoteParams = {
  title: string;
  body: string;
  folder: string;
  account: string;
}
```

### `shortcuts.appendNote(params: NoteAppendParams) → Result<ShortcutResponse>`

```typescript
type NoteAppendParams = {
  title: string;       // Must exactly match existing note title
  folder: string;
  content: string;
}
```

### `shortcuts.revealInFinder(path: string) → Result<ShortcutResponse>`

---

## Module: Finder Integration

### `finder.ensureFolderExists(absolutePath: string) → Result<string>`

Creates folder hierarchy if missing. Never overwrites existing folders. Returns final path.

### `finder.buildPath(params: PathParams) → string`

```typescript
type PathParams = {
  semester?: string;   // "Semester 5"
  subject_code: string;
  unit_name?: string;  // "Unit 1"
  category_name?: string; // "Notes"
}
```

Returns: `~/Documents/ALMS/Semester5/ANN/Unit1/Notes`

### `finder.moveFile(sourcePath: string, destPath: string) → Result<string>`

Moves file. Verifies destination folder exists first. Returns final path.

### `finder.getRootPath() → string`

Returns configured root from settings.

### `finder.checkExists(path: string) → boolean`

---

## Module: Search

### `search.query(q: string, filter?: SearchFilter) → Result<SearchResults>`

```typescript
type SearchFilter = {
  entity_types?: ("item" | "file" | "reminder" | "calendar" | "note")[];
  subject_id?: string;
  due_before?: string;
  due_after?: string;
}

type SearchResults = {
  items: Item[];
  files: File[];
  total: number;
}
```

Phase 1: SQLite FTS or LIKE-based search.
Phase 2: Cross-reference Apple app data (if available).

---

## Module: Dashboard

### `dashboard.getSummary() → Result<DashboardData>`

```typescript
type DashboardData = {
  upcoming_assignments: Item[];   // due_date within 7 days, type=assignment
  upcoming_exams: Item[];         // due_date within 14 days, type=exam
  pending_tasks: Item[];          // status=active, type in [assignment, lab, project]
  recent_files: File[];           // Last 10 imported files
  recent_activity: ActivityLog[]; // Last 20 events
  sync_failures: number;          // Count of failed links
  items_today: Item[];            // Due today
}
```

---

## Module: Sync

### `sync.retryFailed() → Result<SyncRetryReport>`

Retries all `failed` and `retry` status links across all link tables.

### `sync.getStatus() → Result<SyncStatus>`

```typescript
type SyncStatus = {
  pending: number;
  failed: number;
  permanently_failed: number;
  last_sync_at?: string;
}
```

---

## Module: Settings

### `settings.get(key: string) → Result<unknown>`

### `settings.set(key: string, value: unknown) → Result<void>`

### `settings.getAll() → Result<Record<string, unknown>>`

### `settings.reset(key: string) → Result<void>`

Resets a key to its default value.

---

## Module: Activity Logger

### `logger.log(event: LogEvent) → void`

```typescript
type LogEvent = {
  event_type: EventType;
  entity_type?: string;
  entity_id?: string;
  description: string;
  error?: string;
  metadata?: Record<string, unknown>;
}
```

Fire-and-forget. Never blocks the calling operation.

### `logger.query(filter: LogFilter) → Result<ActivityLog[]>`

---

## Module: Subjects

### `subjects.list(includeArchived?: boolean) → Result<Subject[]>`
### `subjects.create(data: SubjectCreate) → Result<Subject>`
### `subjects.update(id: string, data: Partial<SubjectCreate>) → Result<Subject>`
### `subjects.archive(id: string) → Result<void>`
### `subjects.delete(id: string) → Result<void>`

Deleting a subject with existing items is blocked unless all items are also deleted or reassigned.

---

## Shared Type Definitions

```typescript
type ItemType    = "notes" | "assignment" | "exam" | "lab" | "project" | "resource" | "event" | "other"
type Priority    = "low" | "medium" | "high"
type ItemStatus  = "active" | "completed" | "archived"
type SyncStatus  = "pending" | "created" | "updated" | "failed" | "retry" | "completed" | "permanently_failed"
```
