# ALMS - Database Schema

## Overview

- Engine: SQLite 3
- Default location: `~/Library/Application Support/ALMS/alms.db`
- All IDs: UUID v4 as TEXT
- All timestamps: ISO 8601 UTC strings (`2025-06-20T14:30:00Z`)
- All booleans: INTEGER (0 = false, 1 = true)
- Schema versioned via `schema_version` in settings table
- All foreign keys enforced (`PRAGMA foreign_keys = ON`)

---

## Entity Relationship Summary

```
semesters
    └── subjects
            └── units
                    └── categories
                                └── items
                                        ├── files
                                        ├── item_tags → tags
                                        ├── reminder_links
                                        ├── calendar_links
                                        └── notes_links

file_hashes (dedup index)
activity_logs (append-only event log)
settings (key-value config)
```

---

## Table Definitions

### semesters

```sql
CREATE TABLE semesters (
    id          TEXT PRIMARY KEY,
    name        TEXT NOT NULL UNIQUE,  -- "Semester 5", "Semester 6"
    start_date  TEXT,                  -- ISO 8601 date
    end_date    TEXT,
    is_active   INTEGER NOT NULL DEFAULT 0,  -- Only one active at a time
    created_at  TEXT NOT NULL,
    updated_at  TEXT NOT NULL
);
```

Constraint: enforced at application layer — setting `is_active = 1` deactivates the previously active semester.

---

### subjects

```sql
CREATE TABLE subjects (
    id          TEXT PRIMARY KEY,
    semester_id TEXT NOT NULL REFERENCES semesters(id) ON DELETE CASCADE,
    name        TEXT NOT NULL,
    code        TEXT,                 -- Short code: "ANN", "ML", "CN"
    color       TEXT,                 -- Hex: "#FF5733"
    archived    INTEGER NOT NULL DEFAULT 0,
    sort_order  INTEGER NOT NULL DEFAULT 0,
    created_at  TEXT NOT NULL,
    updated_at  TEXT NOT NULL,
    UNIQUE(semester_id, name),
    UNIQUE(semester_id, code)
);
```

Default rows (seeded on first run):

| code | name |
|------|------|
| ANN | ANN |
| ML | Machine Learning |
| CN | Computer Networks |
| FLA | FLA |
| MATH | Mathematics |
| SRW | Short Range Wireless |
| IAF | Indian Art Form |
| CC | Community Connect |

---

### units

```sql
CREATE TABLE units (
    id          TEXT PRIMARY KEY,
    subject_id  TEXT NOT NULL REFERENCES subjects(id) ON DELETE CASCADE,
    name        TEXT NOT NULL,        -- "Unit 1"
    number      INTEGER NOT NULL,     -- 1, 2, 3, 4, 5
    created_at  TEXT NOT NULL,
    UNIQUE(subject_id, number)
);
```

Default: 5 units per subject, created automatically when subject is seeded.

---

### categories

```sql
CREATE TABLE categories (
    id          TEXT PRIMARY KEY,
    unit_id     TEXT NOT NULL REFERENCES units(id) ON DELETE CASCADE,
    name        TEXT NOT NULL,        -- "Notes", "Assignments", "Labs", "PYQs", "Resources"
    type        TEXT NOT NULL,        -- SEE ENUM BELOW
    sort_order  INTEGER NOT NULL DEFAULT 0,
    created_at  TEXT NOT NULL,
    UNIQUE(unit_id, name)
);
```

**Category type ENUM:** `notes` | `assignment` | `lab` | `pyq` | `resource` | `custom`

Default categories per unit: Notes, Assignments, Labs, PYQs, Resources

---

### items

```sql
CREATE TABLE items (
    id          TEXT PRIMARY KEY,
    subject_id  TEXT NOT NULL REFERENCES subjects(id),
    unit_id     TEXT REFERENCES units(id),
    category_id TEXT REFERENCES categories(id),
    type        TEXT NOT NULL,        -- SEE ENUM BELOW
    title       TEXT NOT NULL,
    description TEXT,
    due_date    TEXT,                 -- ISO 8601 date: "2025-06-20"
    due_time    TEXT,                 -- Optional time: "23:59:00"
    priority    TEXT NOT NULL DEFAULT 'medium',  -- low | medium | high
    source      TEXT,                -- Origin: "inbox_text", "inbox_file", "drag_drop"
    status      TEXT NOT NULL DEFAULT 'active',  -- active | completed | archived
    created_at  TEXT NOT NULL,
    updated_at  TEXT NOT NULL
);
```

**Item type ENUM:** `notes` | `assignment` | `exam` | `lab` | `project` | `resource` | `event` | `other`

**Indexes:**
```sql
CREATE INDEX idx_items_subject    ON items(subject_id);
CREATE INDEX idx_items_unit       ON items(unit_id);
CREATE INDEX idx_items_type       ON items(type);
CREATE INDEX idx_items_due_date   ON items(due_date);
CREATE INDEX idx_items_status     ON items(status);
```

---

### files

```sql
CREATE TABLE files (
    id              TEXT PRIMARY KEY,
    item_id         TEXT REFERENCES items(id) ON DELETE SET NULL,
    original_name   TEXT NOT NULL,
    stored_name     TEXT,             -- Renamed filename; NULL if renaming disabled
    stored_path     TEXT NOT NULL,    -- Absolute path: ~/Documents/ALMS/...
    file_hash       TEXT NOT NULL REFERENCES file_hashes(sha256),
    file_size       INTEGER NOT NULL, -- Bytes
    mime_type       TEXT,
    finder_verified INTEGER NOT NULL DEFAULT 1,  -- 0 if file missing from Finder
    created_at      TEXT NOT NULL,
    updated_at      TEXT NOT NULL
);
```

**Indexes:**
```sql
CREATE INDEX idx_files_item   ON files(item_id);
CREATE INDEX idx_files_hash   ON files(file_hash);
CREATE INDEX idx_files_path   ON files(stored_path);
```

---

### file_hashes

Deduplification index. Separate from files to allow fast hash lookups.

```sql
CREATE TABLE file_hashes (
    sha256      TEXT PRIMARY KEY,
    file_id     TEXT NOT NULL REFERENCES files(id),
    detected_at TEXT NOT NULL
);
```

---

### tags

```sql
CREATE TABLE tags (
    id          TEXT PRIMARY KEY,
    name        TEXT NOT NULL UNIQUE,
    created_at  TEXT NOT NULL
);
```

### item_tags

```sql
CREATE TABLE item_tags (
    item_id TEXT NOT NULL REFERENCES items(id) ON DELETE CASCADE,
    tag_id  TEXT NOT NULL REFERENCES tags(id)  ON DELETE CASCADE,
    PRIMARY KEY (item_id, tag_id)
);
```

---

### reminder_links

Tracks ALMS-created reminders in Apple Reminders. One item may have one reminder link.

```sql
CREATE TABLE reminder_links (
    id              TEXT PRIMARY KEY,
    item_id         TEXT NOT NULL UNIQUE REFERENCES items(id) ON DELETE CASCADE,
    reminder_ext_id TEXT,             -- External ID from Apple Reminders (if Shortcut returns one)
    reminder_title  TEXT NOT NULL,
    list_name       TEXT NOT NULL,    -- Reminders list name: "ALMS"
    status          TEXT NOT NULL DEFAULT 'pending',
    last_synced_at  TEXT,
    error_message   TEXT,
    retry_count     INTEGER NOT NULL DEFAULT 0,
    created_at      TEXT NOT NULL,
    updated_at      TEXT NOT NULL
);
```

**Status ENUM:** `pending` | `created` | `updated` | `failed` | `retry` | `completed` | `permanently_failed`

**Indexes:**
```sql
CREATE INDEX idx_reminder_links_item   ON reminder_links(item_id);
CREATE INDEX idx_reminder_links_status ON reminder_links(status);
```

---

### calendar_links

```sql
CREATE TABLE calendar_links (
    id              TEXT PRIMARY KEY,
    item_id         TEXT NOT NULL UNIQUE REFERENCES items(id) ON DELETE CASCADE,
    event_ext_id    TEXT,
    event_title     TEXT NOT NULL,
    calendar_name   TEXT NOT NULL,
    event_date      TEXT NOT NULL,    -- ISO 8601 date
    all_day         INTEGER NOT NULL DEFAULT 1,
    status          TEXT NOT NULL DEFAULT 'pending',
    last_synced_at  TEXT,
    error_message   TEXT,
    retry_count     INTEGER NOT NULL DEFAULT 0,
    created_at      TEXT NOT NULL,
    updated_at      TEXT NOT NULL
);
```

**Indexes:**
```sql
CREATE INDEX idx_calendar_links_item   ON calendar_links(item_id);
CREATE INDEX idx_calendar_links_status ON calendar_links(status);
CREATE INDEX idx_calendar_links_date   ON calendar_links(event_date);
```

---

### notes_links

```sql
CREATE TABLE notes_links (
    id              TEXT PRIMARY KEY,
    item_id         TEXT NOT NULL UNIQUE REFERENCES items(id) ON DELETE CASCADE,
    note_ext_id     TEXT,
    note_title      TEXT NOT NULL,
    folder_name     TEXT NOT NULL,    -- Notes folder: "ALMS" or "ALMS/ANN"
    account         TEXT NOT NULL DEFAULT 'iCloud',  -- iCloud | On My Mac
    status          TEXT NOT NULL DEFAULT 'pending',
    last_synced_at  TEXT,
    error_message   TEXT,
    retry_count     INTEGER NOT NULL DEFAULT 0,
    created_at      TEXT NOT NULL,
    updated_at      TEXT NOT NULL
);
```

---

### activity_logs

Append-only. Never deleted (only archived). Used for dashboard, retry queue, audit.

```sql
CREATE TABLE activity_logs (
    id          TEXT PRIMARY KEY,
    event_type  TEXT NOT NULL,   -- import | error | sync | update | duplicate_prevented
                                  -- | shortcut_call | file_move | retry | settings_change
    entity_type TEXT,            -- item | file | reminder | calendar | note | system
    entity_id   TEXT,
    description TEXT NOT NULL,
    error       TEXT,
    metadata    TEXT,            -- JSON blob: extra context
    created_at  TEXT NOT NULL
);
```

**Indexes:**
```sql
CREATE INDEX idx_activity_type    ON activity_logs(event_type);
CREATE INDEX idx_activity_entity  ON activity_logs(entity_id);
CREATE INDEX idx_activity_created ON activity_logs(created_at);
```

---

### settings

```sql
CREATE TABLE settings (
    key         TEXT PRIMARY KEY,
    value       TEXT NOT NULL,   -- JSON-encoded value
    updated_at  TEXT NOT NULL
);
```

**Default Settings:**

| Key | Default | Description |
|-----|---------|-------------|
| `schema_version` | `"1"` | DB schema version |
| `root_folder` | `"~/Library/Mobile Documents/com~apple~CloudDocs/ALMS"` | iCloud Drive root path (configurable) |
| `current_semester` | `"Semester 5"` | Label for current semester |
| `reminders_list` | `"ALMS"` | Target Reminders list |
| `calendar_name` | `"ALMS"` | Target Calendar |
| `notes_folder` | `"ALMS"` | Target Notes folder |
| `notes_account` | `"iCloud"` | Notes account |
| `file_renaming_enabled` | `true` | Auto-rename imported files |
| `units_per_subject` | `5` | Default units when creating subject |
| `shortcut_invocation` | `"cli"` | `"cli"` or `"url_scheme"` |
| `max_retry_count` | `3` | Max Shortcut retry attempts |
| `seed_default_subjects` | `true` | Seed defaults on first run |
| `first_run_complete` | `false` | Set to true after setup wizard |

---

## Migration Strategy

Migrations stored in `migrations/` folder as numbered SQL files:

```
migrations/
├── 0001_initial_schema.sql
├── 0002_add_due_time.sql
└── ...
```

On app start:
1. Read `settings.schema_version`
2. Run any migrations with higher version number
3. Update `schema_version`

---

## Constraints Summary

- No item may be created without a `subject_id`
- No file may exist without a `stored_path`
- No file may be imported without a `file_hash` entry in `file_hashes`
- Reminder/Calendar/Notes links are UNIQUE per item (one link per app per item)
- `activity_logs` rows are never deleted
