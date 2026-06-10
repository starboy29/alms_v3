# ALMS - Questions & Assumptions

**Do not implement any uncertain requirements without first getting answers to the relevant questions below.**

Last updated: 2025-06-09

---

## RESOLVED

| Q | Question | Answer |
|---|----------|--------|
| Q1 | Technology stack | **Native Swift + SwiftUI** |
| Q2 | Minimum macOS version | **macOS 14 (Sonoma)** |
| Q3 | File storage location | **iCloud Drive** (`~/Library/Mobile Documents/com~apple~CloudDocs/ALMS/`), configurable on first setup, files are **moved** (not copied). Existing files in other locations: out of scope for Phase 1. |
| Q4 | Semester structure | **Add `semesters` table** — subjects belong to a semester, one is active at a time |

---

## CRITICAL — Must Answer Before Implementation

---

### Q1: Technology Stack

What technology stack should ALMS use?

This is the most critical decision. It affects all other choices.

| Option | Stack | Notes |
|--------|-------|-------|
| A | Native Swift + SwiftUI | Best Apple integration, lightest. Requires Xcode + Swift knowledge. |
| B | Electron + Node.js | Familiar web tooling, easier multi-agent parallelism. Heavy (~200MB). |
| C | Tauri + Rust + Web frontend | Light (~10MB), excellent file access, web UI. Rust adds complexity. |
| D | Python backend + Web UI (via local server) | Easy file ops, but macOS distribution is complex. |

**Recommendation:** Option A (SwiftUI) for deepest Apple integration. Option B (Electron) for fastest parallel agent development. Option C (Tauri) as a middle ground.

**Implication of this answer:**
- Affects file system access approach
- Affects how Shortcuts CLI is invoked (shell exec vs NSTask vs Rust Command)
- Affects the UI framework and agent division
- Affects build and distribution

---

### Q2: Minimum macOS Version

What is the minimum macOS version ALMS must support?

- `shortcuts` CLI is available from **macOS 12 (Monterey)**
- macOS 13 (Ventura) adds Shortcuts improvements
- macOS 14 (Sonoma) adds further Shortcuts actions

If the minimum is below macOS 12, a fallback integration strategy is needed for Shortcuts.

---

### Q3: File Storage Location

Where should ALMS store organized files?

**Default assumption:** `~/Documents/ALMS/`

Questions:
- Is this path configurable on first setup?
- Should ALMS use iCloud Drive (`~/Library/Mobile Documents/`)? This would enable iPhone access to files.
- What happens to existing files already organized in another location?
- Should ALMS move files or copy them? (Move assumed — confirm?)

---

### Q4: Semester Structure

Is there a Semester level above Subjects in the database?

The Finder example in the spec shows: `Semester 5 / ANN / Unit 1 / ...`

But the spec's DB tables list does not include a `semesters` table.

Options:
- A: Add a `semesters` table — subjects belong to a semester, one is active at a time
- B: `current_semester` as a settings key — just a label used for Finder folder naming
- C: No semester concept in Phase 1 — add later

**Current assumption:** Option B — `current_semester` is a settings key used only as a folder label. No semester table in Phase 1.

---

## IMPORTANT — Should Answer Before Phase 1

---

### Q5: Apple Reminders List

Which Reminders list should ALMS use?

- A: Single list `ALMS` for all subjects
- B: Per-subject lists (`ALMS - ANN`, `ALMS - ML`)
- C: Configurable in settings

**Assumption:** Single `ALMS` list with subject noted in the reminder title and notes.

---

### Q6: Reminder External IDs

Apple Reminders via Shortcuts does not expose a stable external ID.

ALMS's dedup strategy relies on matching by `title + list + due_date`. This means:
- If the user edits a reminder's title directly in the Reminders app, ALMS loses track of it
- If the same assignment is submitted twice on different days, two reminders will be created

Is this acceptable for Phase 1? Or should ALMS use `Find Reminders` Shortcut to read and cross-check?

---

### Q7: Apple Calendar

Which calendar should ALMS use?

- A: Single calendar `ALMS` for all events
- B: Per-subject calendars
- C: Configurable

**Assumption:** Single `ALMS` calendar, configurable.

---

### Q8: Calendar Event Timing

For assignments and exams, should calendar events be:

- All-day events on the due date?
- Timed events at a specific time (e.g., 9:00 AM)?
- All-day by default, timed only if time is specified?

**Assumption:** All-day by default for assignments/exams unless a specific time is provided in the input.

---

### Q9: Apple Notes — Folder Structure

Where should ALMS create notes?

- A: Single folder `ALMS` (all notes flat inside)
- B: Nested `ALMS/Subject` (one folder per subject)
- C: Configurable

Apple Notes Shortcuts supports folder selection but nested folder creation behavior varies by macOS version.

**Assumption:** Single `ALMS` folder for Phase 1. Subject is recorded in the note title.

---

### Q10: When Does Notes Integration Trigger?

When should ALMS create/update an Apple Note?

The spec is clear that:
- Assignment text → Reminder + Calendar ✓
- Files → Finder ✓
- Notes type (text) → Apple Notes ✓

But unclear:
- Does uploading a file with `type=notes` also create an Apple Note?
- Does any text entry (not just `type=notes`) create a Note?
- Is Notes integration only for explicitly typed `notes` items?

**Assumption:** Notes integration triggers only when `item.type = "notes"` AND the input was a text entry.

---

### Q11: Phase 1 Metadata Extraction

Without AI (which is Phase 3), how should Phase 1 extract metadata?

Options:
- A: Rule-based only — regex + keyword matching. Low confidence = skip and always ask user.
- B: Rule-based + always require user to confirm before routing (even for high-confidence extractions)
- C: Rule-based extract what's possible; required missing fields trigger a focused prompt

**Assumption:** Option C. ALMS extracts what it can via rules, then prompts only for missing required fields (Subject, Type). Due date and other optional fields default to empty if not detected.

---

### Q12: Cross-Check Against Existing Apple Reminders?

Should ALMS use the `Find Reminders` Shortcut to check if a reminder already exists in Apple Reminders before creating one?

- Pro: Prevents duplicates even for manually created reminders
- Con: Slower (requires a Shortcut call before every create), and `Find Reminders` may not support all filter criteria

**Assumption (Phase 1):** No cross-check. ALMS only prevents its own duplicates via `reminder_links` table. Document this limitation clearly.

---

### Q13: App Form Factor

What form should the ALMS application take?

- A: Menu bar app only (always running in background, minimal UI)
- B: Full window app (opens like any macOS app)
- C: Menu bar with a main window (click menu bar icon to open dashboard)
- D: Menu bar for quick capture + separate main window for dashboard

**Assumption:** Option C — menu bar icon for quick capture, click to expand full dashboard window.

---

### Q14: Shortcut Installation Method

How will users install the required Apple Shortcuts?

- A: ALMS ships pre-built `.shortcut` files; user double-clicks each to import
- B: ALMS's setup wizard walks through manual creation step-by-step
- C: ALMS uses `shortcuts import` CLI to auto-install (feasibility needs testing)
- D: Combination — ship `.shortcut` files AND provide setup wizard as fallback

**Assumption:** Option A + D — ship `.shortcut` files with setup wizard as fallback. Confirm whether Apple allows third-party shortcut file distribution.

---

## LOWER PRIORITY — Can Decide During Build

---

### Q15: Multi-Semester Support

Can multiple semesters be active simultaneously?

Or is exactly one semester "active" and the rest are archived?

**Assumption:** Exactly one semester is active (controlled by `current_semester` settings key). Archive/history requires changing the label and re-organizing, or leaving old files in place.

---

### Q16: Archived Subjects

When a subject is archived:
- Is it hidden from the Inbox subject picker?
- Is it still searchable?
- Is its Finder folder preserved as-is?
- Is its Apple Notes/Reminders untouched?

**Assumption:** Archived subjects are hidden from active views but remain in the database and Finder. No Apple app cleanup on archive.

---

### Q17: File Renaming — Default

Is file renaming enabled or disabled by default?

The spec says it is optional and user can disable it. But what is the default state?

**Assumption:** Enabled by default. Pattern: `<SubjectCode>_<Unit>_<Type>_<Date>.<ext>`

---

### Q18: ZIP File Handling

ZIP files are listed as a supported input type. Should ALMS:

- A: Import ZIP as-is (move to destination, register in DB)
- B: Extract ZIP and import each contained file individually
- C: Import as-is for Phase 1; extraction in Phase 2

**Assumption:** Option A for Phase 1 — import as single file. No extraction.

---

### Q19: Dashboard Refresh

How should the dashboard refresh its data?

- A: Real-time (observe DB changes)
- B: On window focus
- C: Manual refresh button only
- D: Polling every N seconds

**Assumption:** On window focus + after every import operation. No polling.

---

### Q20: Default Subjects on First Run

Should ALMS auto-populate the 8 default subjects on first run?

Default subjects from spec:
ANN, Machine Learning, Computer Networks, FLA, Mathematics, Short Range Wireless, Indian Art Form, Community Connect

- A: Auto-create on first run (with confirmation prompt)
- B: Show them as pre-selected defaults in setup wizard (user can deselect)
- C: Start empty, user adds manually

**Assumption:** Option B — setup wizard shows default subjects with checkboxes; user confirms or deselects before first use.

---

## Assumptions Summary Table

| # | Assumption | Confidence | Impact if Wrong |
|---|------------|-----------|----------------|
| A1 | Files stored in ~/Documents/ALMS/ | Medium | Low — path is configurable |
| A2 | SQLite at ~/Library/Application Support/ALMS/alms.db | High | Low |
| A3 | Shortcuts invoked via CLI | Medium | High — entire bridge changes |
| A4 | macOS 12+ required | Medium | Medium — needs fallback strategy |
| A5 | No semesters table in Phase 1 | Medium | Medium — affects DB schema |
| A6 | Single ALMS Reminders list | Medium | Low |
| A7 | Single ALMS Calendar | Medium | Low |
| A8 | Single ALMS Notes folder | Medium | Low |
| A9 | All-day calendar events for assignments/exams | Medium | Low |
| A10 | Notes triggered only for type=notes text entries | Medium | Medium — routing rules change |
| A11 | Phase 1 metadata = rule-based + prompt for missing required fields | High | Low |
| A12 | No cross-check against existing Apple Reminders (Phase 1) | High | Medium — duplicates possible |
| A13 | Menu bar + main window form factor | Low | Medium — affects UI architecture |
| A14 | File renaming enabled by default | Medium | Low |
| A15 | ZIP imported as-is in Phase 1 | High | Low |
| A16 | Default subjects shown in setup wizard (not auto-created silently) | Medium | Low |

---

## How to Resolve

For each critical question, respond to this file or in conversation.

Once resolved, update this document:
- Move the question under a "Resolved" section
- Record the answer
- Note any implementation changes required

No implementation begins on items marked as assumptions until confirmed.
