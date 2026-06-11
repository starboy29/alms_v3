import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel: SettingsViewModel?

    var body: some View {
        Group {
            if let vm = viewModel {
                SettingsContentView(vm: vm)
            } else {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = SettingsViewModel(db: appState.db)
            }
        }
        .navigationTitle("Settings")
    }
}

private struct SettingsContentView: View {
    @Bindable var vm: SettingsViewModel
    @Environment(AppState.self) private var appState

    var body: some View {
        Form {
            storageSection
            appleSection
            semesterSection
            subjectsSection
        }
        .formStyle(.grouped)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Save") { vm.save() }
                    .buttonStyle(.borderedProminent)
            }
        }
        .alert("Saved", isPresented: $vm.showSavedAlert) {
            Button("OK") { vm.showSavedAlert = false }
        } message: {
            Text("Settings have been saved.")
        }
    }

    private var storageSection: some View {
        Section {
            HStack {
                TextField("Root folder path", text: $vm.rootFolder)
                Button("Browse…") { vm.pickFolder() }
                    .buttonStyle(.bordered)
            }
            Text("Files are organized: \(vm.rootFolder.isEmpty ? "~/Documents/ALMS" : vm.rootFolder) / Semester / Subject / Unit / Category")
                .font(.caption)
                .foregroundStyle(.secondary)
        } header: {
            Label("Storage", systemImage: "folder")
        }
    }

    private var appleSection: some View {
        Section {
            LabeledContent("Reminders List") {
                TextField("Inbox", text: $vm.remindersList).multilineTextAlignment(.trailing)
            }
            LabeledContent("Calendar") {
                TextField("ALMS", text: $vm.calendarName).multilineTextAlignment(.trailing)
            }
        } header: {
            Label("Apple Apps", systemImage: "apple.logo")
        }
    }

    private var semesterSection: some View {
        Section {
            ForEach(vm.semesters, id: \.id) { sem in
                HStack {
                    Text(sem.name)
                    if sem.isActive {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                        Text("Active").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    if !sem.isActive {
                        Button("Set Active") { vm.switchSemester(id: sem.id) }
                            .buttonStyle(.bordered)
                    }
                }
            }
            if vm.showNewSemester {
                HStack {
                    TextField("Semester name", text: $vm.newSemesterName)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { vm.addSemester() }
                    Button("Add") { vm.addSemester() }
                        .buttonStyle(.bordered)
                        .disabled(vm.newSemesterName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    Button("Cancel") { vm.showNewSemester = false; vm.newSemesterName = "" }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            HStack {
                Label("Semesters", systemImage: "calendar.badge.clock")
                Spacer()
                if !vm.showNewSemester {
                    Button { vm.showNewSemester = true } label: {
                        Image(systemName: "plus").fontWeight(.medium)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var subjectsSection: some View {
        Section {
            if vm.subjects.isEmpty && !vm.showNewSubject {
                Text("No subjects yet. Tap + to add one.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(vm.subjects, id: \.id) { subject in
                    HStack {
                        if let code = subject.code {
                            SubjectPill(code: code)
                        }
                        VStack(alignment: .leading, spacing: 1) {
                            Text(subject.name)
                            if let code = subject.code {
                                Text(code).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Button("Archive") { vm.archiveSubject(id: subject.id) }
                            .buttonStyle(.borderless)
                            .foregroundStyle(.red)
                    }
                }
            }
            if vm.showNewSubject {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        TextField("Code (e.g. ANN)", text: $vm.newSubjectCode)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 130)
                        TextField("Subject name", text: $vm.newSubjectName)
                            .textFieldStyle(.roundedBorder)
                            .onSubmit { vm.addSubject() }
                    }
                    HStack {
                        Button("Add Subject") { vm.addSubject() }
                            .buttonStyle(.bordered)
                            .disabled(vm.newSubjectName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        Button("Cancel") {
                            vm.showNewSubject = false
                            vm.newSubjectCode = ""
                            vm.newSubjectName = ""
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }
        } header: {
            HStack {
                Label("Subjects — \(vm.activeSemesterName)", systemImage: "book")
                Spacer()
                if !vm.showNewSubject {
                    Button { vm.showNewSubject = true } label: {
                        Image(systemName: "plus").fontWeight(.medium)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
