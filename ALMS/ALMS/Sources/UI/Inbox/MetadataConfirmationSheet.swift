import SwiftUI

struct MetadataConfirmationSheet: View {
    let metadata: ExtractedMetadata
    let db: ALMSDatabase
    let onConfirm: (ConfirmedMetadata) -> Void
    let onCancel: () -> Void

    @State private var subjects: [Subject] = []
    @State private var selectedSubjectId: String = ""
    @State private var units: [ALMSUnit] = []
    @State private var selectedUnitId: String = ""
    @State private var selectedType: ItemType = .assignment
    @State private var title: String = ""
    @State private var hasDueDate: Bool = false
    @State private var dueDateValue: Date = Date()
    @State private var selectedPriority: ItemPriority = .medium

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Confirm Details")
                    .font(.title2).bold()
                Text("ALMS needs a little help — please confirm the subject and type.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Form {
                Picker("Subject", selection: $selectedSubjectId) {
                    Text("Select subject…").tag("")
                    ForEach(subjects, id: \.id) { s in
                        Text("\(s.code.map { "\($0) — " } ?? "")\(s.name)").tag(s.id)
                    }
                }
                .onChange(of: selectedSubjectId) { _, newValue in
                    // Chapters belong to a subject — reload them and clear any stale selection.
                    loadUnits(for: newValue)
                    selectedUnitId = ""
                }

                Picker("Chapter / Unit", selection: $selectedUnitId) {
                    Text("None").tag("")
                    ForEach(units, id: \.id) { u in
                        Text(u.name).tag(u.id)
                    }
                }
                .disabled(units.isEmpty)

                Picker("Type", selection: $selectedType) {
                    ForEach([ItemType.assignment, .exam, .lab, .project, .notes, .resource, .event, .other], id: \.self) { t in
                        Text(t.rawValue.capitalized).tag(t)
                    }
                }

                TextField("Title", text: $title)

                Toggle("Set due date", isOn: $hasDueDate.animation())
                if hasDueDate {
                    DatePicker("Due date", selection: $dueDateValue, displayedComponents: [.date])
                }

                Picker("Priority", selection: $selectedPriority) {
                    ForEach([ItemPriority.low, .medium, .high], id: \.self) { p in
                        Text(p.rawValue.capitalized).tag(p)
                    }
                }
                .pickerStyle(.segmented)
            }
            .formStyle(.grouped)
            .frame(height: 340)

            HStack {
                Button("Cancel", role: .cancel) { onCancel() }
                Spacer()
                Button("Add to ALMS") {
                    let confirmed = ConfirmedMetadata(
                        subjectId: selectedSubjectId,
                        unitId: selectedUnitId.isEmpty ? nil : selectedUnitId,
                        categoryId: nil,
                        type: selectedType,
                        title: title,
                        dueDate: hasDueDate ? DateParser.iso8601Date(from: dueDateValue) : nil,
                        priority: selectedPriority
                    )
                    onConfirm(confirmed)
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedSubjectId.isEmpty || title.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(24)
        .frame(minWidth: 420, maxWidth: 500)
        .onAppear { loadData() }
    }

    private func loadData() {
        title = metadata.title ?? ""
        if let t = metadata.type { selectedType = t }
        // Pre-fill the date picker if the extractor found a yyyy-MM-dd due date.
        if let d = metadata.dueDate, let parsed = Self.parseISODate(d) {
            dueDateValue = parsed
            hasDueDate = true
        }

        if let semester = try? SemesterRepository(db: db).fetchActive() {
            subjects = (try? SubjectRepository(db: db).fetchAll(semesterId: semester.id, includeArchived: false)) ?? []
        }
        selectedSubjectId = metadata.subjectId ?? subjects.first?.id ?? ""

        // Load chapters for the initial subject, and preselect one if the extractor found it.
        loadUnits(for: selectedSubjectId)
        selectedUnitId = metadata.unitId ?? ""
    }

    private func loadUnits(for subjectId: String) {
        guard !subjectId.isEmpty else { units = []; return }
        units = (try? UnitRepository(db: db).fetchAll(subjectId: subjectId)) ?? []
    }

    /// Parses a "yyyy-MM-dd" string (the app's standard due-date format) back into a Date.
    private static func parseISODate(_ string: String) -> Date? {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f.date(from: string)
    }
}

extension ItemType: CaseIterable {
    public static var allCases: [ItemType] {
        [.assignment, .exam, .lab, .project, .notes, .resource, .event, .other]
    }
}

extension ItemPriority: CaseIterable {
    public static var allCases: [ItemPriority] {
        [.low, .medium, .high]
    }
}
