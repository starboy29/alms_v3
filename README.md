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

- Renames and files the item into `Root / Semester 5 / ANN / Unit 1 / Assignments /`
- Creates a Reminder in your **Inbox** list with `#ANN #assignment #ALMS` smart tags and a 9am due-date alarm (EventKit)
- Creates a Calendar event via the `ALMS-CreateCalendarEvent` shortcut
- Indexes the item in Spotlight so you can find it with Cmd+Space
- Sends a macOS notification confirming the item was filed
- Logs everything to SQLite and updates the Dashboard

You never touch Finder, Reminders, or Calendar directly.

Press **Control+Option+Space** from any app to open the Quick Entry panel without switching to ALMS.

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
Universal Inbox (drag-and-drop / text / Quick Entry hotkey)
        ↓
  Metadata Engine
  (AI via Apple Intelligence + regex fallback)
        ↓
   SQLite Database (GRDB)
        ↓
   Routing Engine
   ├── FinderService      →  files into Root/Semester/Subject/Unit/Type, renames to "{Code} - {Title}.ext"
   ├── RemindersService   →  EventKit — Inbox list, real due date, #hashtag smart tags in title
   ├── CalendarService    →  EventKit — calendar event with due date
   ├── SpotlightService   →  CoreSpotlight indexing for system-wide search
   └── NotificationService →  UNUserNotificationCenter — fires on file filed / reminder / event created
```

**Key technical decisions:**

- **Native Swift + SwiftUI** — deepest Apple integration, lightest binary
- **GRDB.swift** — type-safe SQLite with migration support
- **EventKit for both Reminders and Calendar** — `Add New Reminder` and Calendar shortcuts on Tahoe cannot reliably set due dates or pick lists; EventKit does both natively
- **Apple Intelligence / FoundationModels** — used for metadata extraction on macOS 26+; falls back to regex on earlier versions
- **Security-scoped bookmarks** — sandbox-safe write access to the user's chosen root folder across launches
- **Title-embedded `#hashtags`** — the only way to create real smart-stackable Reminders tags programmatically on Tahoe (notes-field hashtags are not parsed by the Reminders app)
- **Carbon `RegisterEventHotKey`** — global hotkey (Control+Option+Space) for the Quick Entry panel, invokable from any app

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
        │   ├── CalendarService.swift    — EventKit calendar event creation
        │   ├── SpotlightService.swift   — CoreSpotlight indexing
        │   ├── NotificationService.swift — UNUserNotificationCenter notifications
        │   ├── GlobalHotKey.swift       — Carbon RegisterEventHotKey for quick entry
        │   ├── DuplicateGuard.swift     — SHA-256 file dedup
        │   └── Metadata/
        │       ├── AIMetadataEngine.swift  — Apple Intelligence / FoundationModels NLP
        │       ├── MetadataEngine.swift    — regex-based subject/type/date extraction
        │       ├── SubjectMatcher.swift
        │       ├── DateParser.swift
        │       └── ExtractedMetadata.swift
        └── UI/
            ├── AppState.swift
            ├── SidebarView.swift
            ├── Inbox/                   — InboxView, InboxViewModel, MetadataConfirmationSheet, FileDescriptionSheet
            ├── Dashboard/               — DashboardView, DashboardViewModel, SyncIssuesView
            ├── Settings/                — SettingsView, SettingsViewModel
            ├── QuickEntry/              — QuickEntryView, QuickEntryManager
            └── Components/              — SubjectPill, TypeBadge, ItemRowView, ItemDetailView, View+Glass
```

---

## Sandbox & Permissions

ALMS is a sandboxed macOS app. It requests:

| Permission | Why |
|---|---|
| `files.user-selected.read-write` | Write filed PDFs into your chosen folder |
| `files.bookmarks.app-scope` | Remember the folder across launches without re-prompting |
| `personal-information.reminders` | Create reminders via EventKit |
| `personal-information.calendars` | Calendar event creation via EventKit; also required for Reminders (both share the CalendarAgent daemon) |

---

## Apple Shortcuts

One shortcut is required: **ALMS-CreateCalendarEvent**

Reminders are created entirely via EventKit — no shortcut needed. The calendar shortcut creates an event with the correct date and title.

ALMS generates an unsigned `.shortcut` file and a Terminal install script. Running the script from Terminal signs and installs it silently. You do not need to do this manually — the Settings screen provides the one-click path.

> **Why not just import the shortcut?** macOS only accepts *signed* shortcut files, and a sandboxed app cannot call `shortcuts sign` (Keychain denied). The Terminal workaround is the only reliable install path.

---

## Roadmap

**Implemented in v1**
- [x] Subject and semester management UI
- [x] Sync issues panel with per-item retry
- [x] AI classification via Apple Intelligence (macOS 26+)
- [x] Global Quick Entry hotkey (Control+Option+Space)
- [x] Spotlight indexing for system-wide search

**Backlog**
- [ ] Unified search inside the ALMS UI
- [ ] OCR for images and scanned PDFs
- [ ] Voice capture
- [ ] Semester archive workflow
- [ ] iPhone Quick Capture via Shortcuts share extension

---

## Design Docs

The following design documents live at the project root:

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
