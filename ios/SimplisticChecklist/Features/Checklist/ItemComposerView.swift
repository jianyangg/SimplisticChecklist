import SwiftUI

struct ItemComposerView: View {
    let onCommit: (String) -> Result<Void, Error>
    let onFailure: (Error) -> Void

    @FocusState private var isFocused: Bool
    @State private var draft = ""

    private var trimmedDraft: String {
        draft.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 10) {
            TextField("New item", text: $draft, axis: .vertical)
                .lineLimit(1...4)
                .textFieldStyle(.roundedBorder)
                .focused($isFocused)
                .submitLabel(.done)
                .onSubmit(commit)
                .accessibilityLabel("New item")
                .accessibilityIdentifier("item-composer-field")

            Button(action: commit) {
                Label("Add", systemImage: "plus")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(trimmedDraft.isEmpty)
            .accessibilityLabel("Add item")
            .accessibilityHint("Adds the text to this checklist")
            .accessibilityIdentifier("item-composer-add-button")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.bar)
        .overlay(alignment: .top) {
            Divider()
        }
    }

    private func commit() {
        guard !trimmedDraft.isEmpty else { return }

        switch onCommit(trimmedDraft) {
        case .success:
            draft = ""
            isFocused = true
        case .failure(let error):
            onFailure(error)
        }
    }
}
