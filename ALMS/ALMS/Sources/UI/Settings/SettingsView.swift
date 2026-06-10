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
            setupSection
            storageSection
            appleSection
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

    private var setupSection: some View {
        Section {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Apple Shortcuts")
                        .font(.body)
                    Text("Check and install the Calendar shortcut")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Open Setup Wizard") {
                    appState.showSetupWizard = true
                }
                .buttonStyle(.bordered)
            }
        } header: {
            Label("Setup", systemImage: "bolt")
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
            LabeledContent("Notes Folder") {
                TextField("ALMS", text: $vm.notesFolder).multilineTextAlignment(.trailing)
            }
            LabeledContent("Notes Account") {
                TextField("iCloud", text: $vm.notesAccount).multilineTextAlignment(.trailing)
            }
        } header: {
            Label("Apple Apps", systemImage: "apple.logo")
        }
    }

    private var subjectsSection: some View {
        Section {
            if vm.subjects.isEmpty {
                Text("No subjects found.")
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
        } header: {
            Label("Subjects — \(vm.activeSemesterName)", systemImage: "book")
        }
    }
}
