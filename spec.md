# ALMS - Academic Life Management System (v2)

## Vision

ALMS (Academic Life Management System) is a macOS-first productivity system that acts as a centralized academic inbox and orchestration engine.

The user should never need to manually decide:

* Where a file belongs
* Which note to update
* Whether a reminder already exists
* Whether a calendar event should be created
* Which folder something should be stored in

The user should only capture information.

ALMS should handle organization automatically.

---

# Core Philosophy

Capture Once.
Organize Automatically.

The user should not interact directly with:

* Finder
* Notes
* Reminders
* Calendar

for organizational purposes.

Those applications remain storage and presentation layers.

ALMS becomes the intelligence layer.

---

# Architectural Philosophy

ALMS is NOT:

* A notes app
* A calendar app
* A task manager
* A file manager

ALMS IS:

A metadata-driven orchestration platform.

The system receives information.

The system determines meaning.

The system updates Apple applications.

The system prevents duplicates.

The system maintains consistency.

---

# Revised Architecture

User
↓
ALMS Inbox
↓
Metadata Engine
↓
SQLite Database
↓
Routing Engine
↓
Apple Shortcuts + Finder
↓
Apple Notes
Apple Reminders
Apple Calendar

---

# Why Apple Shortcuts

Use Apple Shortcuts whenever possible.

Benefits:

* Native Apple integration
* Less custom integration code
* Better reliability
* Future iPhone compatibility
* Easier maintenance

Preferred integrations:

Apple Notes
→ Shortcuts

Apple Reminders
→ Shortcuts

Apple Calendar
→ Shortcuts

Direct API integration should only be used when Shortcuts cannot achieve the required functionality.

---

# Primary User Workflow

The user should have one universal inbox.

The inbox should accept:

* Text
* PDFs
* PPTs
* DOCX
* Images
* Screenshots
* Voice Notes
* Drag and Drop Files

Everything enters through one location.

---

# Example Workflow

Input:

ANN Assignment 2 due June 20

ALMS should:

Detect:

* Subject = ANN
* Type = Assignment
* Due Date = June 20

Then:

Update Database

Call Shortcut:
Create Assignment Reminder

Call Shortcut:
Create Calendar Event

Update Dashboard

Done.

---

# Universal Inbox

This is the most important feature.

The inbox must support:

## Text Entry

Examples:

ANN Assignment due Friday

ML Midsem July 10

CN Quiz next Tuesday

---

## File Upload

Examples:

PDF

PPT

DOCX

ZIP

Images

---

## Drag and Drop

Drop any supported file.

---

## Voice Notes

Future feature.

Voice
↓
Transcription
↓
Metadata Extraction
↓
Routing

---

# Metadata System

This is the heart of ALMS.

Everything must be organized through metadata.

Never organize solely through filenames.

Example:

random.pdf

must still be manageable.

---

## Required Metadata

Subject

Unit

Type

Date Added

---

## Optional Metadata

Due Date

Priority

Tags

Description

Source

---

## Types

Notes

Assignment

Exam

Lab

Project

Resource

Event

Other

---

# Academic Structure

Default Subjects

ANN

Machine Learning

Computer Networks

FLA

Mathematics

Short Range Wireless

Indian Art Form

Community Connect

User can:

Add Subject

Edit Subject

Archive Subject

Delete Subject

---

# Unit System

Default:

Unit 1

Unit 2

Unit 3

Unit 4

Unit 5

Configurable.

---

# Category System

Each unit contains:

Notes

Assignments

Labs

PYQs

Resources

Custom categories allowed.

---

# Finder Integration

ALMS manages academic files.

Example:

Semester 5

ANN
└── Unit 1
├── Notes
├── Assignments
├── Labs
├── PYQs
└── Resources

ML

CN

FLA

Maths

---

# File Import Process

User uploads file.

ALMS:

Step 1:
Determine metadata.

Step 2:
Ask user if uncertain.

Step 3:
Create folders if missing.

Step 4:
Move file.

Step 5:
Register in database.

---

# File Naming

Optional.

Example:

random.pdf

can become

ANN Unit 1 Notes.pdf

User can disable renaming.

---

# Duplicate Prevention

Critical Requirement.

The system must NEVER create duplicates unless explicitly approved.

---

# File Deduplication

Use SHA256.

Store hash.

When importing:

Calculate hash.

If hash exists:

Prompt:

Already imported.

Options:

Skip

Replace

Update Metadata

---

# Folder Deduplication

If folder exists:

Reuse it.

Never create:

Notes (1)

Assignments Copy

Unit 1 New

---

# Reminder Deduplication

Before creating:

Check:

Subject

Unit

Title

Due Date

If matching reminder exists:

Update.

Do not duplicate.

---

# Calendar Deduplication

Before creating:

Check:

Title

Date

Subject

If existing event found:

Update.

Do not duplicate.

---

# Notes Deduplication

Before creating:

Search existing notes.

If matching note exists:

Append or update.

Never duplicate.

---

# Apple Shortcuts Layer

ALMS should communicate with Apple apps through reusable shortcuts.

Examples:

Create Reminder

Update Reminder

Complete Reminder

Create Calendar Event

Update Calendar Event

Append Note

Create Note

Open Finder Location

Reveal File

This creates a modular architecture.

---

# Quick Capture Shortcut

Future feature.

User on iPhone:

Share
↓
Quick Capture Shortcut
↓
ALMS

Examples:

Screenshot

PDF

Webpage

Text

Voice Note

This allows instant capture from any Apple device.

---

# Database

SQLite.

Database is source of truth.

---

# Tables

Subjects

Units

Categories

Items

Files

Tags

Hashes

Reminder Links

Calendar Links

Notes Links

Activity Logs

Settings

---

# Search System

Unified search.

User searches:

ANN Unit 2

ML Notes

Assignments Due This Week

Results should include:

Files

Notes

Reminders

Calendar Events

Metadata

---

# Dashboard

Read-only dashboard.

Display:

Upcoming Assignments

Upcoming Exams

Pending Tasks

Recent Files

Recent Notes

Recent Activity

Import History

---

# Error Recovery

System must never lose data.

Example:

File imported.

Reminder creation fails.

Result:

File remains stored.

Failure logged.

Retry available.

---

# Logging

Track:

Import Events

Errors

Sync Events

Updates

Duplicates Prevented

Shortcut Calls

---

# Settings

Allow configuration of:

Subjects

Units

Categories

Folder Structure

Naming Rules

Shortcut Mapping

AI Provider

Sync Preferences

Import Rules

---

# AI Classification

NOT MVP.

Future feature.

Pipeline:

Input
↓
Classifier
↓
Suggested Metadata
↓
User Confirmation
↓
Routing

Possible outputs:

Subject

Unit

Type

Due Date

Priority

Tags

---

# OCR

Future feature.

Support:

Images

Screenshots

Scanned PDFs

Extract text before classification.

---

# MVP Scope

Build First:

1. Universal Inbox
2. Metadata Engine
3. SQLite Database
4. Finder Integration
5. Duplicate Prevention
6. Apple Shortcuts Integration
7. Basic Dashboard

---

# Phase 2

Apple Reminders via Shortcuts

Apple Calendar via Shortcuts

Apple Notes via Shortcuts

Unified Search

---

# Phase 3

OCR

AI Classification

Voice Capture

iPhone Quick Capture Shortcut

---

# Instructions To Claude Code

Before coding:

Generate:

architecture.md

database_schema.md

api_spec.md

project_structure.md

integration_design.md

shortcut_design.md

sync_strategy.md

deduplication_strategy.md

Then generate:

questions.md

containing every assumption and uncertainty.

Do not implement uncertain requirements.

Ask questions whenever ambiguity exists.

Do not hallucinate features.

Prioritize reliability over automation.

Use parallel agents where possible:

Agent 1:
Frontend

Agent 2:
Backend

Agent 3:
Database

Agent 4:
Finder Integration

Agent 5:
Apple Shortcuts Integration

Agent 6:
Search Engine

Agent 7:
QA and Testing

Agent 8:
Documentation

All modules should be loosely coupled and communicate through well-defined interfaces.
