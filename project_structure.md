# ALMS - Project Structure

## Overview

**Stack confirmed: Native Swift + SwiftUI, macOS 14 Sonoma minimum.**

This is an Xcode project with Swift Package Manager for dependencies. The structure is designed so that Agents 1–8 can work on separate modules with minimal merge conflicts.

---

## Top-Level Structure

```
ALMS/                              # Xcode project root
├── ALMS.xcodeproj/
├── ALMS/                          # Main app target
│   ├── ALMSApp.swift              # @main entry point
│   ├── Info.plist
│   └── Assets.xcassets
│
├── Sources/                       # Swift source modules
│   ├── Inbox/                     # Agent 1 (Frontend) + Agent 2 (Backend)
│   ├── Metadata/                  # Agent 2 (Backend)
│   ├── Database/                  # Agent 3 (Database)
│   ├── Routing/                   # Agent 2 (Backend)
│   ├── Shortcuts/                 # Agent 5 (Shortcuts)
│   ├── Finder/                    # Agent 4 (Finder)
│   ├── Duplicates/                # Agent 2 (Backend)
│   ├── Search/                    # Agent 6 (Search)
│   ├── Dashboard/                 # Agent 1 (Frontend)
│   ├── Sync/                      # Agent 2 (Backend)
│   ├── Settings/                  # Agent 2 (Backend)
│   ├── Logging/                   # Agent 2 (Backend)
│   └── UI/                        # Agent 1 (Frontend)
│
├── docs/                          # All design documents
│   ├── architecture.md
│   ├── database_schema.md
│   ├── api_spec.md
│   ├── shortcut_design.md
│   ├── sync_strategy.md
│   ├── deduplication_strategy.md
│   ├── project_structure.md
│   ├── integration_design.md
│   └── questions.md
│
├── shortcuts/                 # Pre-built Apple Shortcut files
│   ├── ALMS-CreateReminder.shortcut
│   ├── ALMS-UpdateReminder.shortcut
│   ├── ALMS-CompleteReminder.shortcut
│   ├── ALMS-CreateCalendarEvent.shortcut
│   ├── ALMS-UpdateCalendarEvent.shortcut
│   ├── ALMS-CreateNote.shortcut
│   ├── ALMS-AppendNote.shortcut
│   └── ALMS-RevealInFinder.shortcut
│
├── migrations/                # Agent 3 (Database)
│   ├── 0001_initial_schema.sql
│   └── ...
│
├── ALMSTests/                     # Agent 7 (QA) — XCTest unit + integration
│   ├── InboxTests/
│   ├── MetadataTests/
│   ├── DuplicatesTests/
│   ├── DatabaseTests/
│   └── SyncTests/
│
├── ALMSUITests/                   # Agent 7 (QA) — XCUITest end-to-end
│
├── ALMSShortcuts/                 # Pre-built .shortcut files (distributed with app)
│   ├── ALMS-CreateReminder.shortcut
│   ├── ALMS-UpdateReminder.shortcut
│   ├── ALMS-CompleteReminder.shortcut
│   ├── ALMS-CreateCalendarEvent.shortcut
│   ├── ALMS-UpdateCalendarEvent.shortcut
│   ├── ALMS-CreateNote.shortcut
│   ├── ALMS-AppendNote.shortcut
│   └── ALMS-RevealInFinder.shortcut
│
├── Migrations/                    # Agent 3 (Database) — SQL migration files
│   ├── 0001_initial_schema.sql
│   └── ...
│
├── Package.swift                  # Swift Package Manager dependencies
└── spec.md                        # Original specification
```

**Swift Package Manager Dependencies (proposed):**
- `GRDB.swift` — SQLite wrapper
- (No other external deps needed for Phase 1)

---

## Module Responsibilities by Agent

### Agent 1 — Frontend

```
Sources/UI/
├── Views/
│   ├── InboxView.swift           # Universal Inbox — text entry + file drop target
│   ├── DashboardView.swift       # Dashboard — upcoming, recent, activity
│   ├── SettingsView.swift        # Settings panel
│   └── SetupWizardView.swift     # First-run onboarding
├── Components/
│   ├── FileCardView.swift
│   ├── ItemCardView.swift
│   ├── DuplicateDialogView.swift # Conflict resolution sheet
│   └── SyncStatusView.swift      # Sync failure indicator
├── MenuBarView.swift              # MenuBarExtra content
└── ALMSApp.swift                  # @main, WindowGroup, MenuBarExtra
```

**Interfaces with:** Inbox module API, Dashboard module API, Settings module API

---

### Agent 2 — Backend
```
src/
├── inbox/
│   ├── InboxService       # submitText, submitFile, confirmMetadata
│   └── InputNormalizer    # Normalize all input types to standard form
├── metadata/
│   ├── MetadataEngine     # extract(), resolveSubject(), resolveDate()
│   ├── RuleEngine         # Phase 1: keyword/regex extraction rules
│   └── DateParser         # Natural language date resolution
├── routing/
│   ├── RoutingEngine      # route(), execute(), retryFailed()
│   └── RoutingRules       # Type → target app mapping
├── duplicates/
│   ├── DuplicateGuard     # checkFile(), checkReminder(), checkNote(), etc.
│   └── ConflictResolver   # User prompt logic for conflict resolution
├── sync/
│   ├── SyncService        # retryFailed(), getStatus()
│   └── RetryQueue         # Manages failed/retry link states
├── settings/
│   └── SettingsService    # get(), set(), reset(), getAll()
└── logging/
    └── ActivityLogger     # log(), query()
```

---

### Agent 3 — Database
```
src/database/
├── connection.ts          # SQLite connection, PRAGMA settings, FK enforcement
├── migrations.ts          # Migration runner
├── repositories/
│   ├── SubjectRepository
│   ├── UnitRepository
│   ├── CategoryRepository
│   ├── ItemRepository
│   ├── FileRepository
│   ├── FileHashRepository
│   ├── TagRepository
│   ├── ReminderLinkRepository
│   ├── CalendarLinkRepository
│   ├── NotesLinkRepository
│   ├── ActivityLogRepository
│   └── SettingsRepository
└── seed/
    └── default_subjects.sql

migrations/
├── 0001_initial_schema.sql
└── ...
```

---

### Agent 4 — Finder Integration
```
src/finder/
├── FinderService          # ensureFolderExists(), moveFile(), buildPath()
├── PathBuilder            # Constructs Finder paths from metadata
└── OrphanDetector         # Detects files whose stored_path no longer exists
```

---

### Agent 5 — Apple Shortcuts Integration
```
src/shortcuts/
├── ShortcutsBridge        # Core invocation: call(), verifyInstalled(), verifyAll()
├── ReminderShortcuts      # createReminder(), updateReminder(), completeReminder()
├── CalendarShortcuts      # createCalendarEvent(), updateCalendarEvent()
├── NotesShortcuts         # createNote(), appendNote()
├── FinderShortcuts        # revealInFinder()
└── PayloadBuilder         # Builds JSON payloads for each shortcut

shortcuts/                 # The actual .shortcut files (distributed with app)
```

---

### Agent 6 — Search Engine
```
src/search/
├── SearchService          # query(), index updates on item create/update
└── SearchIndexer          # SQLite FTS index management (Phase 1)
```

---

### Agent 7 — QA and Testing
```
tests/
├── unit/
│   ├── metadata/          # MetadataEngine rule tests
│   ├── duplicates/        # DuplicateGuard tests (critical)
│   ├── routing/           # RoutingEngine tests
│   └── database/          # Repository tests
├── integration/
│   ├── inbox_flow/        # End-to-end text submission flow
│   ├── file_import/       # End-to-end file import flow
│   └── sync/              # Sync state machine tests
└── e2e/
    └── shortcuts/         # Shortcut invocation tests (require macOS)
```

---

### Agent 8 — Documentation
```
docs/                      # All design documents (this agent maintains)
src/**/README.md           # Per-module usage docs
shortcuts/README.md        # Shortcut setup guide for users
```

---

## Inter-Module Communication

All modules communicate through the APIs defined in `api_spec.md`. No module imports directly from another module's internals.

```
Frontend  →  calls  →  Backend module APIs
Backend   →  calls  →  Database repositories
Backend   →  calls  →  Shortcuts Bridge
Backend   →  calls  →  Finder Service
Backend   →  calls  →  Activity Logger (fire-and-forget)
```

No circular dependencies. Database layer has no knowledge of upper layers.

---

## Configuration Files

```
alms/
├── .env or config.json    # Environment-specific settings (never commit secrets)
├── settings.json          # App defaults (mirrors settings table defaults)
└── package.json / Cargo.toml / Package.swift   (stack-dependent)
```
