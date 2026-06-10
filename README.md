# ALMS — Academic Life Management System

A macOS app that acts as your academic inbox. Drop in a file or type a note — ALMS figures out the subject, type, and due date, then files it, creates a Reminder, and adds it to your Calendar automatically.

**Capture once. Organize automatically.**

---

## What it does

You type or drop:
```
ANN Assignment 2 due June 20
```

ALMS detects **Subject = ANN**, **Type = Assignment**, **Due = June 20**, then:

- Files the item into `Root / Semester 5 / ANN / Unit 1 / Assignments /`
- Creates a Reminder in your **Inbox** list with tags `#ANN #assignment #ALMS` and a 9am due-date alarm
- Creates a Calendar event via Apple Shortcuts
- Logs everything to SQLite and updates the Dashboard

You never touch Finder, Reminders, or Calendar directly.

---

## Requirements

| Requirement | Version |
|---|---|
| macOS | **26 (Tahoe)** or later |
| Xcode | 16+ |
| Apple Shortcuts | Installed (comes with macOS) |

> Reminders smart-tag stacking (tags shown as chips) requires Tahoe. The app runs on earlier versions but tags appear as plain text.

---

## Quick Start

1. **Clone and open**
   ```
   git clone <repo-url>
   open ALMS/ALMS.xcodeproj
   ```

2. **Build and run** (⌘R in Xcode)

3. **Complete the Setup Wizard**
   - Install the `ALMS-CreateCalendarEvent` shortcut (one-click Terminal script)
   - Pick your root folder (e.g. `~/Documents/ALMS`) — ALMS files everything under it
   - Allow Reminders and Calendar access when prompted

4. **Add your subjects** in Settings → Subjects

5. **Start dropping files or typing** in the Inbox

---

## File Organization

ALMS organizes files into a hierarchy you define:

```
Root Folder/
└── Semester 5/
    └── ANN/
        └── Unit 1/
            ├── Notes/
            ├── Assignments/
            ├── Labs/
            ├── Exams/
            └── Resources/
```

The semester, subject, chapter/unit, and type are all set during import via the metadata confirmation sheet.

---

## Architecture

```
Universal Inbox (drag-and-drop / text)
        ↓
  Metadata Engine
  (subject / type / due-date detection)
        ↓
   SQLite Database (GRDB)
        ↓
   Routing Engine
   ├── FinderService  →  files PDFs into Semester/Subject/Unit/Type
   ├── RemindersService (EventKit)  →  Inbox list, due date, smart tags
   └── ShortcutsBridge  →  ALMS-CreateCalendarEvent shortcut
```

**Key technical decisions:**

- **Native Swift + SwiftUI** — deepest Apple integration, lightest binary
- **GRDB.swift** — type-safe SQLite with migration support
- **EventKit for Reminders** — chosen over Shortcuts because the `Add New Reminder` shortcut action on Tahoe cannot set a due date or choose a specific list reliably; EventKit does both natively
- **Security-scoped bookmarks** — sandbox-safe write access to the user's chosen root folder across launches
- **Title-embedded `#hashtags`** — the only way to create real smart-stackable Reminders tags programmatically on Tahoe (notes-field hashtags are not parsed by the Reminders app)

---

## Project Structure

```
ALMS/
└── ALMS/
    ├── ALMSApp.swift
    ├── ALMS.entitlements
    └── Sources/
        ├── Database/
        │   ├── ALMSDatabase.swift       — GRDB setup, migrations
        │   ├── Migrations/              — versioned schema migrations
        │   ├── Models/                  — Item, Subject, Semester, ALMSFile, …
        │   ├── Repositories/            — typed query wrappers per model
        │   └── Seed/DefaultSeedData.swift
        ├── Services/
        │   ├── InboxService.swift       — orchestrates the full import flow
        │   ├── RoutingEngine.swift      — decides which integrations to call
        │   ├── FinderService.swift      — path building + security-scoped file moves
        │   ├── RemindersService.swift   — EventKit reminder creation
        │   ├── ShortcutsBridge.swift    — runs Apple Shortcuts via shell
        │   ├── ShortcutFileGenerator.swift — generates .shortcut plist + install script
        │   ├── ShortcutsVerifier.swift  — checks required shortcuts exist
        │   ├── DuplicateGuard.swift     — SHA-256 file dedup
        │   └── Metadata/
        │       ├── MetadataEngine.swift — subject/type/date extraction
        │       ├── SubjectMatcher.swift
        │       ├── DateParser.swift
        │       └── ExtractedMetadata.swift
        └── UI/
            ├── AppState.swift
            ├── SidebarView.swift
            ├── Inbox/                   — InboxView, InboxViewModel, MetadataConfirmationSheet
            ├── Dashboard/               — DashboardView, DashboardViewModel
            ├── Settings/                — SettingsView, SettingsViewModel
            ├── Setup/                   — SetupWizardView, SetupWizardViewModel
            └── Components/              — SubjectPill, TypeBadge, ItemRowView
```

---

## Sandbox & Permissions

ALMS is a sandboxed macOS app. It requests:

| Permission | Why |
|---|---|
| `files.user-selected.read-write` | Write filed PDFs into your chosen folder |
| `files.bookmarks.app-scope` | Remember the folder across launches without re-prompting |
| `personal-information.reminders` | Create reminders via EventKit |
| `personal-information.calendars` | Required by EventKit even for reminders (CalendarAgent mach-lookup) |

---

## Apple Shortcuts

One shortcut is required: **ALMS-CreateCalendarEvent**

The Setup Wizard generates an unsigned `.shortcut` file and a Terminal script. Running the script signs it (Terminal is not sandboxed) and installs it silently. You do not need to do this manually.

> **Why not just import the shortcut?** macOS only accepts *signed* shortcut files, and a sandboxed app cannot call `shortcuts sign` (Keychain denied). The Terminal workaround is the only reliable install path.

---

## Roadmap

**Phase 2**
- [ ] Subject management UI (add / rename / archive subjects in-app)
- [ ] Sync status panel (retry failed Reminders/Calendar syncs)
- [ ] Unified search (files, reminders, calendar events, notes)

**Phase 3**
- [ ] OCR for images and scanned PDFs
- [ ] AI classification (auto-suggest subject/type/due date)
- [ ] Voice capture
- [ ] iPhone Quick Capture via Shortcuts share extension

---

## Design Docs

The `docs/` directory at the root of this repo contains the full design documentation written before implementation:

| File | Contents |
|---|---|
| `spec.md` | Product spec and core philosophy |
| `architecture.md` | System layer diagram and module descriptions |
| `database_schema.md` | Full SQLite schema (13 tables) |
| `api_spec.md` | Internal module interfaces |
| `integration_design.md` | Per-integration boundary specs |
| `sync_strategy.md` | Unidirectional sync and retry policy |
| `deduplication_strategy.md` | 6 dedup domains (file, reminder, calendar, folder…) |
| `shortcut_design.md` | Original shortcut design (historical; mostly superseded by EventKit) |
| `questions.md` | Open questions and resolved decisions |

---

## Contributing

This is an early-stage personal project. Issues and PRs are welcome.

When contributing:
- Target **macOS 26 (Tahoe)** — the app uses `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` and `@Observable`
- All ViewModels use `@Observable`; bind with `@Bindable` in views
- DB access is synchronous (GRDB on the main actor — fast local SQLite, no async needed)
- No new Shortcuts integrations — EventKit/native APIs are preferred for reliability

---

## License

MIT
