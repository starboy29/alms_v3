# ALMS - System Architecture

## Overview

ALMS is a macOS-first metadata-driven orchestration platform. It sits between the user's raw input and Apple's native applications. It never duplicates. It never corrupts existing data. SQLite is the single source of truth.

---

## Core Principle

```
User captures → ALMS organizes → Apple apps display
```

Apple Notes, Reminders, Calendar, and Finder are treated as read-only presentation layers from ALMS's perspective. ALMS writes to them; it does not depend on reading from them (Phase 1).

---

## System Layer Diagram

```
┌───────────────────────────────────────────────────────┐
│                   USER INTERFACE                      │
│   Universal Inbox  │  Dashboard  │  Settings          │
└────────────────────────┬──────────────────────────────┘
                         │
┌────────────────────────▼──────────────────────────────┐
│                  METADATA ENGINE                      │
│   Rule-based extraction → User confirmation prompt    │
│   (Phase 3: AI classification layer added here)       │
└────────────────────────┬──────────────────────────────┘
                         │
┌────────────────────────▼──────────────────────────────┐
│              DUPLICATE GUARD  (pre-write)             │
│   File hash check  │  Title+Date match  │  DB lookup  │
└────────────────────────┬──────────────────────────────┘
                         │
┌────────────────────────▼──────────────────────────────┐
│                 SQLITE DATABASE                       │
│         Single source of truth for all state          │
└──────┬──────────────┬────────────────┬────────────────┘
       │              │                │
┌──────▼──────┐ ┌─────▼──────┐ ┌──────▼─────────┐
│  ROUTING    │ │  FINDER    │ │   ACTIVITY     │
│  ENGINE     │ │ INTEGRATION│ │   LOGGER       │
└──────┬──────┘ └─────┬──────┘ └────────────────┘
       │              │
┌──────▼──────────────▼──────────────────────────────┐
│               SHORTCUTS BRIDGE                     │
│   Invokes named Apple Shortcuts via CLI / URL      │
└──────┬──────────────┬──────────────┬───────────────┘
       │              │              │
  ┌────▼────┐   ┌─────▼────┐  ┌─────▼────┐
  │Reminders│   │ Calendar │  │  Notes   │
  └─────────┘   └──────────┘  └──────────┘
```

---

## Modules

### 1. Universal Inbox
- Entry point for all user input
- Accepts: text, PDF, PPT, DOCX, images, ZIP, drag-and-drop
- Normalizes input into a standard pending Item structure
- Triggers Metadata Engine immediately on submission
- Never routes directly — always goes through Metadata → Duplicate Guard

### 2. Metadata Engine
- Phase 1: Rule-based keyword and regex extraction
  - Subject detection via code matching (ANN, ML, CN, FLA…)
  - Type detection via keywords (Assignment, Exam, Quiz, Lab…)
  - Date detection via NLP-light patterns (Friday, June 20, next Tuesday)
- Phase 3: AI-assisted classification (future, pluggable)
- When confidence is low: prompts user to confirm or fill metadata
- Never routes without complete required metadata (Subject, Type)

### 3. Duplicate Guard
- Runs synchronously before every write
- File: SHA256 hash lookup in `file_hashes` table
- Reminder: subject + title + due_date + list lookup in `reminder_links`
- Calendar: title + date + subject lookup in `calendar_links`
- Note: title + folder lookup in `notes_links`
- On duplicate found: prompts user with options (Skip / Replace / Update Metadata)

### 4. SQLite Database
- Single `.db` file — default: `~/Library/Application Support/ALMS/alms.db`
- Stores all items, files, metadata, Apple app link IDs, sync status, activity log
- All writes are transactional
- Database write succeeds independently of any Shortcuts call

### 5. Routing Engine
- Reads item type and metadata from DB
- Determines which Apple apps need to be updated:
  - Assignment / Exam / Lab / Project → Reminder + Calendar Event
  - Notes type → Apple Note
  - File import → Finder move
- Builds payloads for Shortcuts Bridge
- Does not call Shortcuts directly — delegates to bridge

### 6. Shortcuts Bridge
- Invokes Apple Shortcuts using `shortcuts run "ALMS-<Name>" --input-path <json_file>`
- Passes parameters as JSON via temp file
- Reads stdout response
- On success: updates link table with status = `created`, stores external ID if returned
- On failure: status = `failed`, logs error, file and DB entry are preserved

### 7. Finder Integration
- Manages the academic folder hierarchy
- Checks existence before creating any folder
- Never creates: "Notes (1)", "Unit 1 New", etc.
- Moves files to computed destination path
- Supports: create, verify, move, reveal operations

### 8. Activity Logger
- Append-only log of all system events
- Event types: import, error, sync, update, duplicate_prevented, shortcut_call, file_move
- Used for: dashboard Recent Activity, retry queue, audit trail

---

## Data Flow: Text Entry

```
Input: "ANN Assignment 2 due June 20"

1. Inbox.submitText()
2. MetadataEngine.extract()
   → { subject: ANN, type: assignment, title: "Assignment 2", due_date: 2025-06-20 }
3. DuplicateGuard.checkReminder()
   → No duplicate found
4. DB.items.insert()
5. RoutingEngine.route(item)
   → targets: [reminder, calendar]
6. ShortcutsBridge.createReminder({ title: "ANN Assignment 2", due_date: ... })
   → success: reminder_links updated, status = created
7. ShortcutsBridge.createCalendarEvent({ title: "ANN Assignment 2 Due", date: ... })
   → success: calendar_links updated, status = created
8. ActivityLogger.log(import_event)
9. Dashboard refreshed
```

## Data Flow: File Import

```
Input: assignment2_ann.pdf (drag-and-drop)

1. Inbox.submitFile()
2. Files.getHash() → SHA256 computed
3. DuplicateGuard.checkFile(hash)
   → No duplicate found
4. MetadataEngine.extract(file)
   → Uncertain: prompts user for Subject, Unit, Category
5. User confirms: { subject: ANN, unit: Unit 1, category: Assignments }
6. Finder.ensureFolderExists(~/Documents/ALMS/Semester5/ANN/Unit1/Assignments/)
7. Finder.moveFile(source, destination)
8. DB.files.insert({ stored_path, file_hash, item_id })
9. DB.file_hashes.insert({ sha256 })
10. RoutingEngine.route(item)
    → targets: [reminder] (assignment type)
11. ShortcutsBridge.createReminder(...)
12. ActivityLogger.log(import_event)
```

---

## Technology Stack

**Confirmed: Native Swift + SwiftUI. macOS 14 (Sonoma) minimum.**

| Layer | Technology |
|-------|-----------|
| Language | Swift 5.9+ |
| UI Framework | SwiftUI (macOS 14 App target) |
| Database | SQLite via [GRDB.swift](https://github.com/groue/GRDB.swift) or SQLite.swift |
| File Storage | iCloud Drive (`~/Library/Mobile Documents/com~apple~CloudDocs/ALMS/`) — configurable |
| Shell execution | `Process` (formerly NSTask) for `shortcuts run` CLI calls |
| File operations | `FileManager` |
| Hashing | `CryptoKit.SHA256` |
| Drag & Drop | SwiftUI `.onDrop` modifier |
| Menu bar | `MenuBarExtra` (macOS 13+) |
| App container | `~/Library/Application Support/ALMS/` (SQLite db, logs) |

**Build toolchain:** Xcode 15+ required. Swift Package Manager for dependencies.

---

## Agent Assignments (Phase 1 Implementation)

Stack confirmed: **Swift + SwiftUI, macOS 14 Sonoma**.

| Agent | Responsibility | Interfaces With |
|-------|---------------|----------------|
| Agent 1 - Frontend | Universal Inbox UI, Dashboard, Settings UI | Inbox module, Dashboard module |
| Agent 2 - Backend | Metadata Engine, Routing Engine, Sync | DB, Shortcuts Bridge |
| Agent 3 - Database | Schema, migrations, CRUD layer | All modules |
| Agent 4 - Finder | Folder creation, file move, verify | DB files table |
| Agent 5 - Shortcuts | Bridge, invocation, param passing | Routing Engine |
| Agent 6 - Search | Unified search across all entities | DB read-only |
| Agent 7 - QA | Test coverage, dedup validation | All modules |
| Agent 8 - Docs | API docs, user guide | All modules |

All agents communicate through well-defined module interfaces — see api_spec.md.

---

## Error Recovery Guarantee

Any partial failure must leave the system in a consistent, recoverable state:

- File moved to Finder → DB entry written → Shortcuts failed → File is NOT lost
- DB write failed → File is NOT moved
- Shortcut partial (Reminder created, Calendar failed) → Calendar link marked `failed`, retry available

**No operation is all-or-nothing except the DB transaction itself.**
