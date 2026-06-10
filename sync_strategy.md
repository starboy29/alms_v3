# ALMS - Sync Strategy

## Core Principle

SQLite is the **source of truth**. Apple apps are **write targets**.

ALMS does not read from Apple apps to derive state (Phase 1). It only writes to them.

All state about what ALMS has sent to Apple apps is recorded in the three link tables:
- `reminder_links`
- `calendar_links`
- `notes_links`

---

## Sync Direction (Phase 1)

```
ALMS SQLite  ──── write only ────►  Apple Reminders
ALMS SQLite  ──── write only ────►  Apple Calendar
ALMS SQLite  ──── write only ────►  Apple Notes
ALMS SQLite  ──── file move  ────►  Finder
```

No reads from Apple apps. If a user deletes something in Reminders directly, ALMS does not detect it. That item's link status remains `created` in the DB.

Phase 2 consideration: polling Apple apps to detect completions (e.g., a reminder marked done → mark item complete in ALMS). This requires investigation into Shortcut read capabilities.

---

## Sync States

```
pending ──► created
        └──► failed ──► retry ──► created
                               └──► permanently_failed
created ──► updated
        └──► completed
```

| Status | Meaning | Next Action |
|--------|---------|-------------|
| `pending` | Queued, not yet attempted | Attempt on next routing pass |
| `created` | Successfully created in Apple app | Update on metadata change |
| `updated` | Successfully updated | — |
| `failed` | Attempt failed | Retry up to max_retry_count |
| `retry` | Queued for retry | Retry on next sync pass |
| `completed` | Marked complete (reminder done / event passed) | No further action |
| `permanently_failed` | Max retries exceeded | Show alert to user |

---

## Sync Trigger Points

### 1. On Item Create
When a new item is inserted into the DB:
1. RoutingEngine.route(itemId) is called
2. Routing plan is built based on item type
3. Each target is inserted into the appropriate link table with `status = pending`
4. `sync.execute(plan)` is called immediately
5. On success: status → `created`
6. On failure: status → `failed`, error logged

### 2. On Item Update
When an item's metadata is modified:
1. Check which link tables have existing `created` entries for this item
2. For each: call corresponding Update shortcut
3. On success: status → `updated`
4. On failure: status → `failed`

### 3. On App Launch
On every ALMS startup:
1. Query all `failed` and `retry` links
2. Execute retry pass
3. Respect `retry_count` — if >= `max_retry_count`, set to `permanently_failed`

### 4. Manual Retry
User can trigger from Dashboard:
1. "Retry Failed Syncs" button
2. Calls `sync.retryFailed()`
3. Updates dashboard on completion

---

## Routing Rules

The Routing Engine applies these rules to determine Apple app targets:

| Item Type | Targets |
|-----------|---------|
| `assignment` | Reminders + Calendar |
| `exam` | Reminders + Calendar |
| `lab` | Reminders |
| `project` | Reminders + Calendar |
| `event` | Calendar |
| `notes` | Notes (if text entry) |
| `resource` | Finder only |
| `other` | Reminders (if has due_date) |

**File imports:** Always → Finder. May also trigger Reminders if item has due_date.

---

## Deduplication Before Sync

Before calling any Create shortcut, DuplicateGuard is checked against ALMS's own link tables:

```
Before ALMS-CreateReminder:
  → Check reminder_links WHERE item_id = X
  → If exists with status IN (created, updated, completed):
       Call ALMS-UpdateReminder instead of ALMS-CreateReminder

Before ALMS-CreateCalendarEvent:
  → Check calendar_links WHERE item_id = X
  → If exists: call update

Before ALMS-CreateNote:
  → Check notes_links WHERE item_id = X
  → If exists with title: call ALMS-AppendNote instead
```

This ensures ALMS never duplicates its own outputs.

---

## Retry Policy

```
Attempt 1: immediate (on create)
Attempt 2: delayed 5 seconds
Attempt 3: delayed 30 seconds
After 3 failures: status = permanently_failed, alert shown
```

Delay values are configurable via settings `retry_delays` key (array of seconds).

Maximum retry count: settings `max_retry_count` key (default: 3).

---

## Error Recovery Guarantee

The system is designed so that **a Shortcut failure never causes data loss**.

```
Scenario: File imported → Reminder creation fails

What happens:
  ✓ File is moved to Finder destination
  ✓ files table row is committed
  ✓ items table row is committed
  ✗ ALMS-CreateReminder fails
  → reminder_links.status = failed
  → activity_logs records the failure
  → Dashboard shows 1 sync failure
  → User can retry
  → File is not lost. Item is not lost.
```

```
Scenario: Reminder created → Calendar event creation fails

  ✓ reminder_links.status = created
  ✗ calendar_links.status = failed
  → Reminder exists in Apple Reminders
  → Calendar event will be retried
  → No rollback of the successful reminder
```

ALMS does not perform cross-app transactions. Each Apple app sync is independent.

---

## Finder Sync (Special Case)

Finder is not synced via Shortcuts in the traditional sense. File import is a one-time operation:

1. `finder.ensureFolderExists(destination)` — idempotent
2. `finder.moveFile(source, destination)` — moves the file
3. `files.stored_path` is updated in DB

There is no ongoing Finder sync. The file is moved once and tracked by path.

**Orphan detection:** On dashboard load, ALMS verifies that `files.stored_path` still resolves to a real file. If not, `finder_verified = 0` is set and a warning is shown.

---

## Sync Log

Every sync attempt is recorded in `activity_logs`:

```json
{
  "event_type": "shortcut_call",
  "entity_type": "reminder",
  "entity_id": "<reminder_link_id>",
  "description": "Called ALMS-CreateReminder for item <item_id>",
  "error": null,
  "metadata": {
    "shortcut": "ALMS-CreateReminder",
    "params": { "title": "ANN Assignment 2", "list": "ALMS" },
    "status": "created",
    "duration_ms": 1240
  }
}
```

Failed calls include the error message and stderr output.

---

## Phase 2: Read-Back Sync (Not in MVP)

Phase 2 may introduce:
- Reading Reminders completion status via `Find Reminders` Shortcut
- Detecting deleted events in Calendar
- Updating ALMS item status when Apple-side changes are detected
- Scheduled background poll (e.g., every 15 minutes)

This requires investigation into Shortcut read capabilities and will be designed separately.

---

## Offline Behavior

All SQLite and Finder operations work offline.

Shortcuts calls require the target Apple app to be accessible (always true on macOS — apps don't require network unless iCloud sync is involved).

If a Shortcut call fails due to a permissions issue on first run (Shortcuts sandbox), it is logged as `failed` and retried normally.
