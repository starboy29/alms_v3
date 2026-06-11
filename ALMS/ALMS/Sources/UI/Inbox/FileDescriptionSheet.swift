import SwiftUI

struct FileDescriptionSheet: View {
    let filename: String
    let isProcessing: Bool
    let reviewInterpretation: FileInterpretation?
    let onSubmit: (String) -> Void
    let onConfirmReview: (FileInterpretation) -> Void
    let onBack: () -> Void
    let onCancel: () -> Void

    @State private var description = ""
    @State private var reviewCode = ""
    @State private var reviewName = ""
    @State private var reviewUnit = ""
    @State private var reviewFolder = ""
    @State private var reviewTitle = ""

    var body: some View {
        Group {
            if reviewInterpretation != nil {
                reviewView
            } else {
                inputView
            }
        }
        .onChange(of: reviewInterpretation) { _, newValue in
            if let v = newValue {
                reviewCode = v.subjectCode
                reviewName = v.subjectName
                reviewUnit = v.unitName
                reviewFolder = v.folderName
                reviewTitle = v.title
            }
        }
    }

    // MARK: - Input step

    private var inputView: some View {
        VStack(alignment: .leading, spacing: 20) {
            inputHeader
            descriptionEditor
            hint
            inputButtons
        }
        .padding(24)
        .frame(width: 480)
    }

    private var inputHeader: some View {
        HStack(spacing: 10) {
            Image(systemName: "doc.badge.plus")
                .font(.title2)
                .foregroundStyle(Color.accentColor)
            VStack(alignment: .leading, spacing: 2) {
                Text("What is this file?")
                    .font(.headline)
                Text(filename)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
        }
    }

    private var descriptionEditor: some View {
        ZStack(alignment: .topLeading) {
            TextEditor(text: $description)
                .frame(minHeight: 100, maxHeight: 180)
                .font(.body)
                .padding(6)
                .scrollContentBackground(.hidden)

            if description.isEmpty {
                Text("e.g. \"Important topics for ANN Unit 3\"\nor \"ML past year exam 2024\"\nor \"OS lab report experiment 4\"")
                    .font(.body)
                    .foregroundStyle(.tertiary)
                    .padding(.top, 14)
                    .padding(.leading, 11)
                    .allowsHitTesting(false)
            }
        }
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.2)))
    }

    private var hint: some View {
        HStack(spacing: 6) {
            Image(systemName: "sparkles")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("AI will detect the subject and create any missing folders automatically.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var inputButtons: some View {
        HStack {
            Button("Cancel") { onCancel() }
                .buttonStyle(.bordered)
                .disabled(isProcessing)
            Spacer()
            Button {
                onSubmit(description.trimmingCharacters(in: .whitespacesAndNewlines))
            } label: {
                if isProcessing {
                    HStack(spacing: 6) {
                        ProgressView().controlSize(.small)
                        Text("Analysing…")
                    }
                } else {
                    Label("File It", systemImage: "arrow.right.circle.fill")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isProcessing)
        }
    }

    // MARK: - Review step

    private var reviewView: some View {
        VStack(alignment: .leading, spacing: 20) {
            reviewHeader
            reviewFields
            reviewButtons
        }
        .padding(24)
        .frame(width: 480)
    }

    private var reviewHeader: some View {
        HStack(spacing: 10) {
            Image(systemName: "questionmark.circle.fill")
                .font(.title2)
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text("Please confirm the details")
                    .font(.headline)
                Text("I'm not fully certain — check and edit before filing.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private var reviewFields: some View {
        VStack(spacing: 10) {
            fieldRow("Subject code", text: $reviewCode, placeholder: "e.g. ANN")
            fieldRow("Subject name", text: $reviewName, placeholder: "e.g. Artificial Neural Networks")
            fieldRow("Unit", text: $reviewUnit, placeholder: "e.g. Unit 3 (optional)")
            fieldRow("Folder", text: $reviewFolder, placeholder: "e.g. Important Topics")
            fieldRow("File title", text: $reviewTitle, placeholder: "e.g. Unit 3 Key Topics")
        }
    }

    private func fieldRow(_ label: String, text: Binding<String>, placeholder: String) -> some View {
        HStack(spacing: 10) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 88, alignment: .trailing)
            TextField(placeholder, text: text)
                .textFieldStyle(.roundedBorder)
        }
    }

    private var reviewButtons: some View {
        HStack {
            Button("← Back") { onBack() }
                .buttonStyle(.bordered)
                .disabled(isProcessing)
            Spacer()
            Button {
                let interp = FileInterpretation(
                    subjectCode: reviewCode.trimmingCharacters(in: .whitespaces),
                    subjectName: reviewName.trimmingCharacters(in: .whitespaces),
                    unitName: reviewUnit.trimmingCharacters(in: .whitespaces),
                    folderName: {
                        let f = reviewFolder.trimmingCharacters(in: .whitespaces)
                        return f.isEmpty ? "Notes" : f
                    }(),
                    title: reviewTitle.trimmingCharacters(in: .whitespaces),
                    isUnsure: false
                )
                onConfirmReview(interp)
            } label: {
                if isProcessing {
                    HStack(spacing: 6) {
                        ProgressView().controlSize(.small)
                        Text("Filing…")
                    }
                } else {
                    Label("Confirm & File", systemImage: "checkmark.circle.fill")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(
                (reviewCode.trimmingCharacters(in: .whitespaces).isEmpty &&
                 reviewName.trimmingCharacters(in: .whitespaces).isEmpty) || isProcessing
            )
        }
    }
}
