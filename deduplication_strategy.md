# ALMS - Deduplication Strategy

## Principle

The system must NEVER create duplicates unless explicitly approved by the user.

Duplicate prevention runs **before every write operation** — to the database, to Finder, and to Apple apps. No write bypasses the guard.

---

## Four Deduplication Domains

| Domain | Detection Method | On Duplicate Found |
|--------|-----------------|-------------------|
| Files | SHA256 hash | Prompt: Skip / Replace / Update Metadata |
| Reminders | Subject + Title + Due Date + List | Update existing, not create new |
| Calendar Events | Title + Date + Calendar | Update existing, not create new |
| Notes | Title + Folder | Append to existing, not create new |
| Folders | Exact path existence check | Reuse existing, never create variant |
| Items (DB) | Subject + Type + Title + Due Date | Prompt user on conflict |

---

## Domain 1: File Deduplication

### Algorithm

```
1. User submits file
2. Compute SHA256(file_bytes)
3. Query: SELECT * FROM file_hashes WHERE sha256 = ?
4. If row found:
   a. Fetch associated File and Item records
   b. Present duplicate dialog to user:
      - "This file was already imported as [stored_name] on [date]"
      - Option A: Skip (do nothing)
      - Option B: Replace (overwrite stored file, keep same metadata)
      - Option C: Update Metadata (keep file, update subject/unit/type)
5. If not found:
   a. Proceed with import
   b. INSERT into file_hashes AFTER successful file move
```

### Hash Computation

- Algorithm: SHA256
- Computed on raw file bytes before any rename or move
- Stored in `file_hashes.sha256` (TEXT, primary key)
- Also stored in `files.file_hash` for join convenience

### Edge Cases

| Case | Handling |
|------|---------|
| Same file, different name | Hash matches → duplicate detected |
| Same name, different content | Hash differs → import as new file |
| File moved externally after import | `finder_verified = 0` on next check; not a dedup case |
| File re-imported after Replace | Old hash removed, new hash inserted |

---

## Domain 2: Reminder Deduplication

### Algorithm

```
1. Before calling ALMS-CreateReminder:
2. Check ALMS's OWN reminder_links table:
   SELECT * FROM reminder_links
   WHERE item_id = ?
   AND status IN ('created', 'updated', 'pending')
3. If found → call ALMS-UpdateReminder instead
4. If not found → call ALMS-CreateReminder

For cross-check against all ALMS reminders (same item, same context):
SELECT * FROM reminder_links rl
JOIN items i ON rl.item_id = i.id
WHERE i.subject_id = ?
  AND rl.reminder_title LIKE ?
  AND i.due_date = ?
  AND rl.list_name = ?
```

### Matching Criteria

| Field | Comparison |
|-------|-----------|
| subject_id | Exact match |
| title | Case-insensitive LIKE |
| due_date | Exact date match |
| list_name | Exact match |

### Limitations

ALMS cannot read Apple Reminders directly (Phase 1). If the user manually created a reminder with the same title before ALMS, a duplicate MAY be created in Apple Reminders. ALMS only prevents its own duplicates via its link tables.

**[QUESTION Q12: Should ALMS use Shortcut "Find Reminders" to cross-check against all existing Reminders?]**

---

## Domain 3: Calendar Event Deduplication

### Algorithm

```
1. Before calling ALMS-CreateCalendarEvent:
2. Check calendar_links:
   SELECT * FROM calendar_links
   WHERE item_id = ?
   AND status IN ('created', 'updated', 'pending')
3. If found → call ALMS-UpdateCalendarEvent
4. If not found → call ALMS-CreateCalendarEvent

Cross-item dedup check:
SELECT * FROM calendar_links cl
JOIN items i ON cl.item_id = i.id
WHERE cl.event_title LIKE ?
  AND cl.event_date = ?
  AND cl.calendar_name = ?
```

### Matching Criteria

| Field | Comparison |
|-------|-----------|
| event_title | Case-insensitive LIKE |
| event_date | Exact date match |
| calendar_name | Exact match |

---

## Domain 4: Notes Deduplication

### Algorithm

```
1. Before calling ALMS-CreateNote:
2. Check notes_links:
   SELECT * FROM notes_links
   WHERE folder_name = ?
     AND note_title = ?
     AND status IN ('created', 'updated', 'pending')
3. If found → call ALMS-AppendNote instead of ALMS-CreateNote
4. If not found → call ALMS-CreateNote
```

### Key Constraint

Apple Notes via Shortcuts does not prevent duplicate note creation. If ALMS calls ALMS-CreateNote twice with the same title and folder, Apple Notes creates two separate notes.

**ALMS's notes_links table is the only guard.** This is reliable as long as:
1. The note was created through ALMS (not manually)
2. The note was not deleted by the user

If the user deletes an ALMS note manually, the next ALMS write to that title will create a new note (correct behavior — the old one is gone).

---

## Domain 5: Folder Deduplication

### Algorithm

```
1. finder.ensureFolderExists(path):
2. Check if directory exists at path
3. If exists → return existing path (do NOT create)
4. If not exists → create directory and all parent directories
5. Never create: "Notes (1)", "Unit 1 New", "Assignments Copy"
```

### Implementation

```
function ensureFolderExists(path: string): string {
  if (directoryExists(path)) {
    return path;  // Already exists, reuse
  }
  mkdirp(path);   // Create with all parents
  return path;
}
```

Folder existence is checked every time, not cached. This prevents stale state if the user moves a folder externally.

---

## Domain 6: Item (Database) Deduplication

### Algorithm

For text entries that describe an existing academic item:

```
1. User submits: "ANN Assignment 2 due June 20"
2. Metadata extracted: { subject: ANN, type: assignment, title: "Assignment 2", due: June 20 }
3. Check items table:
   SELECT * FROM items
   WHERE subject_id = ?
     AND type = 'assignment'
     AND title LIKE '%Assignment 2%'
     AND due_date = '2025-06-20'
4. If found:
   - Show: "This looks like an existing item: [Assignment 2 - ANN - June 20]"
   - Options: View Existing / Update Metadata / Create New Anyway
5. If not found:
   - Create new item
```

This prevents creating two separate "ANN Assignment 2" items if the user submits the same assignment twice.

---

## Duplicate Resolution UI

When a duplicate is detected, the user sees a prompt:

**For files:**
```
┌──────────────────────────────────────────────┐
│ Duplicate File Detected                       │
│                                               │
│ "assignment2.pdf" was already imported        │
│ as "ANN Unit1 Assignment2.pdf" on June 1      │
│ Located: ALMS/Semester5/ANN/Unit1/Assignments │
│                                               │
│ [ Skip ]  [ Replace ]  [ Update Metadata ]    │
└──────────────────────────────────────────────┘
```

**For items:**
```
┌──────────────────────────────────────────────┐
│ Similar Item Already Exists                   │
│                                               │
│ ANN Assignment 2 — Due June 20               │
│ Created: June 1 | Status: Active              │
│                                               │
│ [ View Existing ]  [ Update ]  [ Create New ] │
└──────────────────────────────────────────────┘
```

---

## Audit Trail

Every duplicate detection is logged to `activity_logs`:

```json
{
  "event_type": "duplicate_prevented",
  "entity_type": "file",
  "entity_id": "<file_id>",
  "description": "Duplicate file detected: SHA256 matches existing file <original_name>",
  "metadata": {
    "sha256": "abc123...",
    "existing_file_id": "<id>",
    "user_choice": "skip"
  }
}
```

Dashboard shows total "Duplicates Prevented" count from this log.
