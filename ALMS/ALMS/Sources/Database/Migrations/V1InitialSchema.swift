import GRDB

enum V1InitialSchema {
    static func register(in migrator: inout DatabaseMigrator) {
        migrator.registerMigration("v1_initial_schema") { db in
            try db.create(table: "semesters") { t in
                t.column("id", .text).primaryKey()
                t.column("name", .text).notNull().unique()
                t.column("start_date", .text)
                t.column("end_date", .text)
                t.column("is_active", .boolean).notNull().defaults(to: false)
                t.column("created_at", .text).notNull()
                t.column("updated_at", .text).notNull()
            }

            try db.create(table: "subjects") { t in
                t.column("id", .text).primaryKey()
                t.column("semester_id", .text).notNull()
                    .references("semesters", onDelete: .cascade)
                t.column("name", .text).notNull()
                t.column("code", .text)
                t.column("color", .text)
                t.column("archived", .boolean).notNull().defaults(to: false)
                t.column("sort_order", .integer).notNull().defaults(to: 0)
                t.column("created_at", .text).notNull()
                t.column("updated_at", .text).notNull()
                t.uniqueKey(["semester_id", "name"])
            }

            try db.create(table: "units") { t in
                t.column("id", .text).primaryKey()
                t.column("subject_id", .text).notNull()
                    .references("subjects", onDelete: .cascade)
                t.column("name", .text).notNull()
                t.column("number", .integer).notNull()
                t.column("created_at", .text).notNull()
                t.column("updated_at", .text).notNull()
                t.uniqueKey(["subject_id", "number"])
            }

            try db.create(table: "categories") { t in
                t.column("id", .text).primaryKey()
                t.column("unit_id", .text).notNull()
                    .references("units", onDelete: .cascade)
                t.column("name", .text).notNull()
                t.column("type", .text).notNull()
                t.column("sort_order", .integer).notNull().defaults(to: 0)
                t.column("created_at", .text).notNull()
                t.column("updated_at", .text).notNull()
                t.uniqueKey(["unit_id", "name"])
            }

            try db.create(table: "items") { t in
                t.column("id", .text).primaryKey()
                t.column("subject_id", .text).notNull()
                    .references("subjects", onDelete: .cascade)
                t.column("unit_id", .text).references("units")
                t.column("category_id", .text).references("categories")
                t.column("type", .text).notNull()
                t.column("title", .text).notNull()
                t.column("description", .text)
                t.column("due_date", .text)
                t.column("due_time", .text)
                t.column("priority", .text).notNull().defaults(to: "medium")
                t.column("source", .text)
                t.column("status", .text).notNull().defaults(to: "active")
                t.column("created_at", .text).notNull()
                t.column("updated_at", .text).notNull()
            }

            try db.create(table: "files") { t in
                t.column("id", .text).primaryKey()
                t.column("item_id", .text).references("items", onDelete: .setNull)
                t.column("original_name", .text).notNull()
                t.column("stored_name", .text)
                t.column("stored_path", .text).notNull()
                t.column("file_hash", .text).notNull()
                t.column("file_size", .integer).notNull()
                t.column("mime_type", .text)
                t.column("finder_verified", .boolean).notNull().defaults(to: true)
                t.column("created_at", .text).notNull()
                t.column("updated_at", .text).notNull()
            }

            try db.create(table: "file_hashes") { t in
                t.column("sha256", .text).primaryKey()
                t.column("file_id", .text).notNull()
                    .references("files")
                t.column("detected_at", .text).notNull()
            }

            try db.create(table: "tags") { t in
                t.column("id", .text).primaryKey()
                t.column("name", .text).notNull().unique()
                t.column("created_at", .text).notNull()
            }

            try db.create(table: "item_tags") { t in
                t.column("item_id", .text).notNull()
                    .references("items", onDelete: .cascade)
                t.column("tag_id", .text).notNull()
                    .references("tags", onDelete: .cascade)
                t.primaryKey(["item_id", "tag_id"])
            }

            try db.create(table: "reminder_links") { t in
                t.column("id", .text).primaryKey()
                t.column("item_id", .text).notNull().unique()
                    .references("items", onDelete: .cascade)
                t.column("reminder_ext_id", .text)
                t.column("reminder_title", .text).notNull()
                t.column("list_name", .text).notNull()
                t.column("status", .text).notNull().defaults(to: "pending")
                t.column("last_synced_at", .text)
                t.column("error_message", .text)
                t.column("retry_count", .integer).notNull().defaults(to: 0)
                t.column("created_at", .text).notNull()
                t.column("updated_at", .text).notNull()
            }

            try db.create(table: "calendar_links") { t in
                t.column("id", .text).primaryKey()
                t.column("item_id", .text).notNull().unique()
                    .references("items", onDelete: .cascade)
                t.column("event_ext_id", .text)
                t.column("event_title", .text).notNull()
                t.column("calendar_name", .text).notNull()
                t.column("event_date", .text).notNull()
                t.column("all_day", .boolean).notNull().defaults(to: true)
                t.column("status", .text).notNull().defaults(to: "pending")
                t.column("last_synced_at", .text)
                t.column("error_message", .text)
                t.column("retry_count", .integer).notNull().defaults(to: 0)
                t.column("created_at", .text).notNull()
                t.column("updated_at", .text).notNull()
            }

            try db.create(table: "notes_links") { t in
                t.column("id", .text).primaryKey()
                t.column("item_id", .text).notNull().unique()
                    .references("items", onDelete: .cascade)
                t.column("note_ext_id", .text)
                t.column("note_title", .text).notNull()
                t.column("folder_name", .text).notNull()
                t.column("account", .text).notNull().defaults(to: "iCloud")
                t.column("status", .text).notNull().defaults(to: "pending")
                t.column("last_synced_at", .text)
                t.column("error_message", .text)
                t.column("retry_count", .integer).notNull().defaults(to: 0)
                t.column("created_at", .text).notNull()
                t.column("updated_at", .text).notNull()
            }

            try db.create(table: "activity_logs") { t in
                t.column("id", .text).primaryKey()
                t.column("event_type", .text).notNull()
                t.column("entity_type", .text)
                t.column("entity_id", .text)
                t.column("description", .text).notNull()
                t.column("error", .text)
                t.column("metadata", .text)
                t.column("created_at", .text).notNull()
            }

            try db.create(table: "settings") { t in
                t.column("key", .text).primaryKey()
                t.column("value", .text).notNull()
                t.column("updated_at", .text).notNull()
            }

            // Indexes
            try db.create(index: "idx_subjects_semester", on: "subjects", columns: ["semester_id"])
            try db.create(index: "idx_items_subject", on: "items", columns: ["subject_id"])
            try db.create(index: "idx_items_type", on: "items", columns: ["type"])
            try db.create(index: "idx_items_due_date", on: "items", columns: ["due_date"])
            try db.create(index: "idx_items_status", on: "items", columns: ["status"])
            try db.create(index: "idx_files_item", on: "files", columns: ["item_id"])
            try db.create(index: "idx_files_hash", on: "files", columns: ["file_hash"])
            try db.create(index: "idx_reminder_links_status", on: "reminder_links", columns: ["status"])
            try db.create(index: "idx_calendar_links_status", on: "calendar_links", columns: ["status"])
            try db.create(index: "idx_activity_logs_type", on: "activity_logs", columns: ["event_type"])
            try db.create(index: "idx_activity_logs_created", on: "activity_logs", columns: ["created_at"])
        }
    }
}
