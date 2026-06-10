# ALMS - Apple Shortcuts Design

## Overview

Apple Shortcuts act as the integration bridge between ALMS and Apple's native apps. ALMS writes to Shortcuts; Shortcuts write to the Apple app. This avoids reverse-engineering private APIs, maximizes reliability, and preserves future iPhone compatibility.

---

## Invocation Method

ALMS calls shortcuts via the macOS `shortcuts` CLI:

```bash
shortcuts run "ALMS-CreateReminder" --input-path /tmp/alms_payload_<uuid>.json
```

**Why CLI over URL scheme:**
- URL scheme has a character limit for input data
- CLI supports large JSON payloads
- CLI output can be captured (stdout) for return values
- CLI works from background processes without UI focus

**macOS version requirement:** macOS 12 (Monterey) or later for `shortcuts` CLI.

**[QUESTION Q2: Confirm minimum macOS version target. See questions.md]**

---

## Invocation Protocol

```
ALMS Backend
    │
    ├── 1. Build params as dict/object
    ├── 2. Serialize to JSON string
    ├── 3. Write to /tmp/alms_<uuid>.json
    ├── 4. Execute: shortcuts run "ALMS-<Name>" --input-path /tmp/alms_<uuid>.json
    ├── 5. Capture stdout (JSON response from shortcut)
    ├── 6. Delete temp file
    └── 7. Parse response → update link table
```

**Timeout:** 30 seconds per shortcut call. If timeout exceeded → status = `failed`.

---

## Shortcut Naming Convention

All ALMS shortcuts are prefixed with `ALMS-` and use PascalCase.

Required shortcuts:

| Shortcut Name | Apple App | Purpose |
|---------------|-----------|---------|
| ALMS-CreateReminder | Reminders | Create new reminder |
| ALMS-UpdateReminder | Reminders | Update existing reminder |
| ALMS-CompleteReminder | Reminders | Mark reminder complete |
| ALMS-CreateCalendarEvent | Calendar | Create new event |
| ALMS-UpdateCalendarEvent | Calendar | Update existing event |
| ALMS-CreateNote | Notes | Create new note |
| ALMS-AppendNote | Notes | Append text to existing note |
| ALMS-RevealInFinder | Finder | Open and reveal path in Finder |

---

## Shortcut Definitions

---

### ALMS-CreateReminder

**Purpose:** Create a new reminder in Apple Reminders.

**Input JSON:**
```json
{
  "title": "ANN Assignment 2",
  "notes": "Subject: ANN | Type: Assignment | Due: June 20",
  "due_date": "2025-06-20",
  "due_time": "23:59:00",
  "list": "ALMS",
  "priority": "medium"
}
```

**Shortcut Actions:**
1. `Receive Input` → Dictionary
2. `Get Value from Dictionary` → key: `title` → save as `title`
3. `Get Value from Dictionary` → key: `due_date` → save as `due_date`
4. `Get Value from Dictionary` → key: `due_time` → save as `due_time`
5. `Get Value from Dictionary` → key: `notes` → save as `notes`
6. `Get Value from Dictionary` → key: `list` → save as `list`
7. `Combine Date and Time` → `due_date` + `due_time`
8. `Add New Reminder` → Title: `title`, Notes: `notes`, Due Date: combined, List: `list`
9. Return `{"status": "created"}`

**Output JSON:**
```json
{
  "status": "created"
}
```

**Note:** Apple Reminders via Shortcuts does not currently return a stable external ID. ALMS tracks reminders by `title + list + due_date` for update/dedup operations.

---

### ALMS-UpdateReminder

**Purpose:** Update an existing reminder's due date or notes.

**Input JSON:**
```json
{
  "match_title": "ANN Assignment 2",
  "match_list": "ALMS",
  "new_title": "ANN Assignment 2",
  "new_due_date": "2025-06-22",
  "new_due_time": "23:59:00",
  "new_notes": "Deadline extended"
}
```

**Shortcut Actions:**
1. `Receive Input` → Dictionary
2. `Find Reminders` where Title is `match_title` and List is `match_list`
3. If found:
   - `Set Due Date` on reminder to `new_due_date` + `new_due_time`
   - `Set Notes` on reminder
   - Return `{"status": "updated"}`
4. If not found:
   - Return `{"status": "not_found"}`

**Output JSON:**
```json
{
  "status": "updated"
}
```

---

### ALMS-CompleteReminder

**Purpose:** Mark an existing reminder as complete.

**Input JSON:**
```json
{
  "match_title": "ANN Assignment 2",
  "match_list": "ALMS"
}
```

**Shortcut Actions:**
1. `Find Reminders` where Title is `match_title` in List `match_list`
2. `Mark as Completed`
3. Return `{"status": "completed"}`

---

### ALMS-CreateCalendarEvent

**Purpose:** Create a new all-day or timed event in Apple Calendar.

**Input JSON:**
```json
{
  "title": "ANN Assignment 2 Due",
  "start_date": "2025-06-20",
  "start_time": "09:00:00",
  "end_date": "2025-06-20",
  "end_time": "10:00:00",
  "all_day": true,
  "calendar": "ALMS",
  "notes": "Subject: ANN | Assignment 2"
}
```

**Shortcut Actions:**
1. `Receive Input` → Dictionary
2. Extract fields
3. If `all_day` is true: `Add New Event` → all-day on `start_date`
4. If `all_day` is false: `Add New Event` → timed with start/end
5. Return `{"status": "created"}`

---

### ALMS-UpdateCalendarEvent

**Purpose:** Update an existing calendar event.

**Input JSON:**
```json
{
  "match_title": "ANN Assignment 2 Due",
  "match_date": "2025-06-20",
  "match_calendar": "ALMS",
  "new_title": "ANN Assignment 2 Due (Extended)",
  "new_date": "2025-06-22"
}
```

**Shortcut Actions:**
1. `Find Events` where Title is `match_title` on `match_date` in Calendar `match_calendar`
2. If found: update title and/or date
3. Return status

---

### ALMS-CreateNote

**Purpose:** Create a new note in Apple Notes.

**Input JSON:**
```json
{
  "title": "ANN Unit 1 Notes",
  "body": "## ANN - Unit 1\n\nContent here...",
  "folder": "ALMS",
  "account": "iCloud"
}
```

**Shortcut Actions:**
1. `Receive Input` → Dictionary
2. `Create Note` → Name: `title`, Body: `body`, in Folder: `folder`, Account: `account`
3. Return `{"status": "created"}`

**Important:** If a note with the same title already exists in the folder, Apple Notes will create a duplicate. ALMS Duplicate Guard must run before calling this shortcut.

---

### ALMS-AppendNote

**Purpose:** Append text to an existing note. MUST check for existence in ALMS before calling.

**Input JSON:**
```json
{
  "match_title": "ANN Unit 1 Notes",
  "match_folder": "ALMS",
  "content": "\n\n---\n## Added on 2025-06-09\nNew content here."
}
```

**Shortcut Actions:**
1. `Find Notes` where Name is `match_title` in Folder `match_folder`
2. If found: `Append to Note` → append `content`
3. Return `{"status": "appended"}` or `{"status": "not_found"}`

---

### ALMS-RevealInFinder

**Purpose:** Open Finder to a specific file or folder path.

**Input JSON:**
```json
{
  "path": "~/Documents/ALMS/Semester5/ANN/Unit1/Notes"
}
```

**Shortcut Actions:**
1. `Receive Input` → Dictionary
2. `Get Value` → key: `path`
3. `Reveal in Finder` or `Open File` with path

---

## Setup Wizard Requirements

On first launch, ALMS must:

1. Detect macOS version — warn if < 12.0
2. Run `shortcuts.verifyAll()` — check each required shortcut exists
3. For each missing shortcut:
   - Display installation instructions
   - Provide downloadable `.shortcut` file (if ALMS ships them)
   - Or step-by-step manual setup guide
4. Verify required Apple Reminders list exists (create if missing)
5. Verify required Apple Calendar exists (create if missing)
6. Verify required Apple Notes folder exists (create if missing)
7. Confirm root Finder folder path
8. Mark `first_run_complete = true` in settings

---

## Shortcut Distribution

**[QUESTION Q14: How should users install ALMS shortcuts?]**

Options being considered:

| Option | Description | Feasibility |
|--------|-------------|------------|
| Pre-built files | Ship `.shortcut` files with the app; user double-clicks to import | Feasible, but Apple may gate import with a permission prompt |
| Setup wizard | ALMS walks user through creating each shortcut manually | Works on all macOS versions, but tedious |
| iCloud sharing | Share shortcuts via iCloud link | Requires user to have iCloud |
| Auto-install via CLI | `shortcuts import` command | Requires investigation |

---

## Limitations and Workarounds

| Limitation | Workaround |
|-----------|------------|
| Reminders doesn't return stable external IDs via Shortcuts | Match by title + list + due_date |
| Calendar doesn't return stable external IDs via Shortcuts | Match by title + date + calendar |
| Notes: duplicate creation if same title exists | ALMS Duplicate Guard runs before every Create call |
| Shortcuts can time out on slow machines | 30s timeout with retry mechanism |
| Shortcuts may prompt for permission on first run | Setup wizard handles initial permission grants |
| Notes AppendNote requires exact title match | ALMS stores exact title in notes_links table |
