import SwiftUI

struct ListNamePrompt: View {
    let title: String
    let initialName: String
    let existingNames: [String]
    let onCommit: (String) -> Result<Void, Error>

    @Environment(\.dismiss) private var dismiss
    @FocusState private var isFocused: Bool
    @State private var draft: String
    @State private var validationMessage: String?

    init(
        title: String,
        initialName: String = "",
        existingNames: [String] = [],
        onCommit: @escaping (String) -> Result<Void, Error>
    ) {
        self.title = title
        self.initialName = initialName
        self.existingNames = existingNames
        self.onCommit = onCommit
        _draft = State(initialValue: initialName)
    }

    private var trimmedName: String {
        draft.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("List name", text: $draft)
                        .focused($isFocused)
                        .submitLabel(.done)
                        .textInputAutocapitalization(.sentences)
                        .onSubmit(commit)
                        .accessibilityLabel("List name")
                        .accessibilityIdentifier("list-name-field")
                } footer: {
                    VStack(alignment: .leading, spacing: 4) {
                        if let validationMessage {
                            Text(validationMessage)
                                .foregroundStyle(.red)
                                .accessibilityAddTraits(.isStaticText)
                        }

                        Text("\(draft.count)/80")
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .monospacedDigit()
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel) { dismiss() }
                        .accessibilityIdentifier("cancel-list-button")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: commit)
                        .disabled(trimmedName.isEmpty)
                        .accessibilityIdentifier("save-list-button")
                }
            }
            .onAppear {
                isFocused = true
            }
        }
    }

    private func commit() {
        guard let error = validationError else {
            switch onCommit(trimmedName) {
            case .success:
                dismiss()
            case .failure(let error):
                validationMessage = error.localizedDescription
            }
            return
        }

        validationMessage = error
    }

    private var validationError: String? {
        do {
            _ = try ChecklistInputValidator.listName(draft, existingNames: existingNames)
            return nil
        } catch {
            return error.localizedDescription
        }
    }
}
