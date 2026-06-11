import SwiftUI
import UniformTypeIdentifiers

struct InboxView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel: InboxViewModel?

    var body: some View {
        Group {
            if let vm = viewModel {
                InboxContentView(vm: vm)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = InboxViewModel(db: appState.db)
            }
            if let text = appState.quickEntryPendingText {
                viewModel?.inputText = text
                appState.quickEntryPendingText = nil
            }
        }
        .onChange(of: appState.quickEntryPendingText) { _, newValue in
            if let text = newValue {
                viewModel?.inputText = text
                appState.quickEntryPendingText = nil
            }
        }
        .navigationTitle("Universal Inbox")
    }
}

private struct InboxContentView: View {
    @Bindable var vm: InboxViewModel
    @State private var detailRow: InboxRow?

    var body: some View {
        VStack(spacing: 0) {
            inputPanel
            Divider()
            itemsList
        }
        .sheet(item: $detailRow, onDismiss: { vm.loadRecentItems() }) { row in
            ItemDetailView(row: row, db: vm.db, onRetry: { vm.loadRecentItems() })
        }
        .sheet(isPresented: $vm.showConfirmation) {
            if let meta = vm.pendingMetadata {
                MetadataConfirmationSheet(
                    metadata: meta,
                    db: vm.db,
                    onConfirm: { vm.confirmMetadata($0) },
                    onCancel:  { vm.dismissConfirmation() }
                )
            }
        }
        .sheet(isPresented: $vm.showFileDescription, onDismiss: { vm.cancelFileDescription() }) {
            if let path = vm.pendingFileDescriptionPath {
                FileDescriptionSheet(
                    filename: URL(fileURLWithPath: path).lastPathComponent,
                    isProcessing: vm.isProcessing,
                    reviewInterpretation: vm.pendingReviewInterpretation,
                    onSubmit: { vm.submitFileWithDescription($0) },
                    onConfirmReview: { vm.confirmReviewAndFile($0) },
                    onBack: { vm.clearReview() },
                    onCancel: { vm.cancelFileDescription() }
                )
            }
        }
        .alert("Error", isPresented: $vm.showError) {
            Button("OK") { vm.showError = false }
        } message: {
            Text(vm.errorMessage ?? "")
        }
        .alert("Clear Inbox", isPresented: $vm.showClearConfirm) {
            Button("Clear All", role: .destructive) { vm.clearAll() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Archive all \(vm.recentItems.count) items? They'll be removed from the inbox but kept in the database.")
        }
        .toolbar {
            if !vm.recentItems.isEmpty {
                ToolbarItem(placement: .primaryAction) {
                    Button("Clear All") { vm.showClearConfirm = true }
                        .foregroundStyle(.red)
                }
            }
        }
    }

    private var inputPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                TextField("e.g. ANN Assignment 2 due June 20", text: $vm.inputText)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { vm.submit() }
                Button {
                    vm.submit()
                } label: {
                    if vm.isProcessing {
                        ProgressView().controlSize(.small)
                    } else {
                        Label("Submit", systemImage: "arrow.right.circle.fill")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(vm.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || vm.isProcessing)
            }

            dropZone
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }

    private var dropZone: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .stroke(
                    vm.isDragTargeted ? Color.accentColor : Color.secondary.opacity(0.25),
                    style: StrokeStyle(lineWidth: 1.5, dash: [6, 3])
                )
                .background(
                    vm.isDragTargeted ? Color.accentColor.opacity(0.06) : Color.clear,
                    in: RoundedRectangle(cornerRadius: 10)
                )
                .frame(height: 72)

            HStack(spacing: 16) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.down.doc")
                        .foregroundStyle(vm.isDragTargeted ? Color.accentColor : Color.secondary)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Drop a file here")
                            .font(.callout)
                            .foregroundStyle(vm.isDragTargeted ? Color.accentColor : Color.secondary)
                        Text("PDF, DOCX, PPT, ZIP, images")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }

                Divider().frame(height: 28)

                Button {
                    vm.openFilePicker()
                } label: {
                    Label("Choose File…", systemImage: "folder")
                        .font(.callout)
                }
                .buttonStyle(.bordered)
            }
        }
        .onDrop(of: [.fileURL], isTargeted: $vm.isDragTargeted) { providers in
            guard let provider = providers.first else { return false }
            _ = provider.loadDataRepresentation(forTypeIdentifier: UTType.fileURL.identifier) { data, _ in
                guard let data,
                      let str = String(data: data, encoding: .utf8),
                      let url = URL(string: str) else { return }
                DispatchQueue.main.async { vm.handleDroppedFile(at: url.path) }
            }
            return true
        }
    }

    private var itemsList: some View {
        Group {
            if vm.recentItems.isEmpty {
                ContentUnavailableView(
                    "Inbox is empty",
                    systemImage: "tray",
                    description: Text("Type something above or drop a file to get started.")
                )
            } else {
                List(vm.recentItems) { row in
                    ItemRowView(item: row.item, subjectCode: row.subjectCode, unitName: row.unitName)
                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                        .contentShape(Rectangle())
                        .onTapGesture { detailRow = row }
                }
                .listStyle(.plain)
            }
        }
    }
}
