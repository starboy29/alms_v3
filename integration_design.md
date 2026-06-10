# ALMS - Integration Design

## Overview

ALMS integrates with four external systems. This document specifies how each integration is designed, the data flow, error handling, and the boundary between ALMS's responsibility and the external system's responsibility.

---

## Integration Map

```
ALMS Core
    │
    ├── Apple Reminders  ←→  via Apple Shortcuts CLI
    ├── Apple Calendar   ←→  via Apple Shortcuts CLI
    ├── Apple Notes      ←→  via Apple Shortcuts CLI
    └── Finder           ←→  via direct file system operations
```

---

## Integration 1: Apple Reminders

### Communication Method
Apple Shortcuts CLI (`shortcuts run "ALMS-CreateReminder" --input-path <json>`)

### ALMS Responsibilities
- Determine when a reminder should be created (Routing Engine)
- Build reminder parameters: title, due date, list, notes, priority
- Call the Shortcut
- Record the outcome in `reminder_links`
- Retry on failure

### Apple Reminders Responsibilities
- Store the reminder
- Display it to the user
- Trigger notifications at due date
- Sync to iCloud / iPhone (handled by Apple)

### Data Passed to Apple Reminders

```json
{
  "title": "ANN Assignment 2",
  "notes": "Subject: ANN | Type: Assignment | Added via ALMS",
  "due_date": "2025-06-20",
  "due_time": "23:59:00",
  "list": "ALMS",
  "priority": "medium"
}
```

### What ALMS Does NOT Control
- Notification scheduling (Apple manages this)
- iCloud sync timing
- Reminder completion triggers (Phase 1)
- Visual appearance in Reminders app

### Deduplication Boundary
ALMS prevents duplicates within its own created reminders (via `reminder_links` table). It cannot prevent a user from manually creating a reminder with the same title before ALMS existed.

---

## Integration 2: Apple Calendar

### Communication Method
Apple Shortcuts CLI

### ALMS Responsibilities
- Create events for assignment due dates, exams, labs
- Update events when metadata changes
- Record event link in `calendar_links`

### Apple Calendar Responsibilities
- Store and display the event
- Sync to iCloud / iPhone
- Trigger Calendar notifications

### Data Passed to Apple Calendar

```json
{
  "title": "ANN Assignment 2 Due",
  "start_date": "2025-06-20",
  "all_day": true,
  "calendar": "ALMS",
  "notes": "Subject: ANN | Assignment 2 | Due: June 20\nAdded via ALMS"
}
```

### Event Timing Rules

| Item Type | Event Style |
|-----------|------------|
| Assignment | All-day on due_date |
| Exam | All-day on exam_date |
| Lab | All-day or timed (if time known) |
| Project | All-day milestone on due_date |
| Event | Timed if time provided, otherwise all-day |

**[QUESTION Q8: Confirm all-day vs timed preference for assignments and exams.]**

---

## Integration 3: Apple Notes

### Communication Method
Apple Shortcuts CLI

### ALMS Responsibilities
- Create subject/unit notes when text content is submitted
- Append new content to existing notes
- Track notes in `notes_links`

### Apple Notes Responsibilities
- Store note content
- Render formatted text
- Sync to iCloud

### Data Passed to Apple Notes (Create)

```json
{
  "title": "ANN Unit 1 Notes",
  "body": "# ANN — Unit 1\n\n---\n\n## Added on 2025-06-09\n\nContent here.",
  "folder": "ALMS",
  "account": "iCloud"
}
```

### Folder Structure in Notes

**[QUESTION Q9: Single ALMS folder vs nested ALMS/Subject folders?]**

Option A (flat):
```
Notes App
└── ALMS/
    ├── ANN Unit 1 Notes
    ├── ANN Unit 2 Notes
    └── ML Unit 1 Notes
```

Option B (nested by subject — requires Shortcuts support):
```
Notes App
└── ALMS/
    ├── ANN/
    │   ├── Unit 1 Notes
    │   └── Unit 2 Notes
    └── ML/
        └── Unit 1 Notes
```

**When Notes Integration Triggers:**

| Input Type | Notes Action |
|-----------|-------------|
| Text entry with type=notes | Create or Append note for subject/unit |
| File upload with type=notes | No note by default (file goes to Finder) |
| Text entry other types | No note (reminder + calendar instead) |

**[QUESTION Q10: Confirm exactly when Apple Note creation is triggered.]**

---

## Integration 4: Finder

### Communication Method
Direct file system operations (no Shortcut needed).

### ALMS Responsibilities
- Create folder hierarchy on import
- Move files from inbox/temp location to academic hierarchy
- Never create duplicate folders
- Track stored_path in database
- Detect orphaned files on startup

### File System Operations Used

| Operation | How |
|-----------|-----|
| Check folder exists | `fs.existsSync(path)` or `stat(path)` |
| Create folder | `mkdir -p path` (recursive) |
| Move file | `fs.rename(src, dest)` or `mv` |
| List folder | `fs.readdirSync(path)` |
| Get file size | `fs.statSync(path).size` |
| Compute SHA256 | Platform crypto library on file bytes |

### Folder Hierarchy Rule

```
<root_folder>/<semester>/<subject_code>/<unit>/<category>/
```

Example:
```
~/Documents/ALMS/Semester5/ANN/Unit1/Assignments/
~/Documents/ALMS/Semester5/ML/Unit2/Notes/
~/Documents/ALMS/Semester5/CN/Unit3/Labs/
```

Spaces in path names are handled by the OS. ALMS normalizes folder names (no special characters).

### File Naming on Import

If `file_renaming_enabled = true`:
```
Original: random.pdf
New name: ANN_Unit1_Assignment2_2025-06-09.pdf
```

Pattern: `<subject_code>_<unit_name>_<type>_<date>.<ext>`

If disabled: file is moved with original name.

**[QUESTION Q17: Confirm default for file renaming — on or off?]**

### ALMS Does NOT
- Monitor the Finder folder for external changes (Phase 1)
- Prevent the user from moving files externally
- Sync changes made outside ALMS back into the database

---

## Integration Architecture: Shared Patterns

### Parameter Passing to Shortcuts

```
1. Build params dictionary/object in ALMS
2. JSON.stringify(params)
3. Write to temp file: /tmp/alms_<uuid>.json
4. Run: shortcuts run "ALMS-Name" --input-path /tmp/alms_<uuid>.json
5. Capture stdout (JSON string from shortcut)
6. JSON.parse(stdout) to get response
7. Delete temp file
8. Handle response
```

### Response Handling

All shortcuts return a JSON string on stdout:
```json
{"status": "created"}
{"status": "updated"}
{"status": "not_found"}
{"status": "error", "message": "..."}
```

If shortcut returns non-JSON or empty stdout → treat as error.

### Permission Handling

On first run, macOS may prompt for permission when a Shortcut accesses:
- Reminders (permission dialog)
- Calendar (permission dialog)
- Notes (permission dialog)

The ALMS setup wizard should:
1. Run each shortcut once with test data to trigger permission prompts
2. Guide the user through approving each permission
3. Record that permissions have been granted

---

## External ID Tracking

Apple's Shortcuts layer has limited external ID support:

| App | Shortcut Returns ID? | ALMS Strategy |
|-----|---------------------|---------------|
| Reminders | No reliable ID | Match by title + list + due_date |
| Calendar | No reliable ID | Match by title + date + calendar |
| Notes | No reliable ID | Match by title + folder |

If future macOS versions expose IDs through Shortcuts, ALMS will store them in `*_ext_id` columns. The matching fallback will remain as a safety net.

---

## Integration Health Check

ALMS exposes a health check function run on launch:

```
shortcuts.verifyAll() → checks all 8 shortcuts exist
finder.getRootPath() → verifies root folder is accessible
database.ping() → verifies SQLite file is readable/writable
```

Any failure is surfaced in the dashboard with a remediation suggestion.
