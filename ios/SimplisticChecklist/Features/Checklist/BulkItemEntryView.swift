import SwiftUI

struct BulkItemEntryView: View {
    let onCommit: ([String]) -> Result<Void, Error>

    @Environment(\.dismiss) private var dismiss
    @FocusState private var isFocused: Bool
    @State private var draft = ""
    @State private var validationMessage: String?

    private var nonemptyLineCount: Int {
        draft.components(separatedBy: .newlines).reduce(into: 0) { count, line in
            if !line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                count += 1
            }
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextEditor(text: $draft)
                        .frame(minHeight: 180)
                        .focused($isFocused)
                        .accessibilityLabel("Checklist items")
                        .accessibilityIdentifier(ChecklistAccessibility.bulkItemEditor)
                } header: {
                    Text("One item per line")
                } footer: {
                    VStack(alignment: .leading, spacing: 6) {
                        if let validationMessage {
                            Text(validationMessage)
                                .foregroundStyle(.red)
                        }
                        Text(ChecklistStrings.itemsToAdd(nonemptyLineCount))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Add Multiple Items")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add Items", action: commit)
                        .disabled(nonemptyLineCount == 0)
                        .accessibilityIdentifier(ChecklistAccessibility.bulkItemAddButton)
                }
            }
            .onAppear { isFocused = true }
        }
    }

    private func commit() {
        do {
            let titles = try ChecklistBulkItemParser.titles(from: draft)
            switch onCommit(titles) {
            case .success:
                dismiss()
            case .failure(let error):
                validationMessage = error.localizedDescription
            }
        } catch {
            validationMessage = error.localizedDescription
        }
    }
}
