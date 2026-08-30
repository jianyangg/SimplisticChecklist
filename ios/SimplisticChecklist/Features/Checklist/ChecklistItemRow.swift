import SwiftUI

struct ChecklistItemRow: View {
    let item: ChecklistItem
    let allowsInlineEditing: Bool
    let onToggle: () -> Void
    let onCommitEdit: (String) -> Result<Void, Error>
    let onDelete: () -> Void
    let onMoveRequested: () -> Void
    let onFailure: (Error) -> Void

    @FocusState private var isTitleFocused: Bool
    @State private var draftTitle: String
    @State private var isEditing = false
    @State private var localValidationMessage: String?

    init(
        item: ChecklistItem,
        allowsInlineEditing: Bool = true,
        onToggle: @escaping () -> Void,
        onCommitEdit: @escaping (String) -> Result<Void, Error>,
        onDelete: @escaping () -> Void,
        onMoveRequested: @escaping () -> Void = {},
        onFailure: @escaping (Error) -> Void = { _ in }
    ) {
        self.item = item
        self.allowsInlineEditing = allowsInlineEditing
        self.onToggle = onToggle
        self.onCommitEdit = onCommitEdit
        self.onDelete = onDelete
        self.onMoveRequested = onMoveRequested
        self.onFailure = onFailure
        _draftTitle = State(initialValue: item.title)
    }

    var body: some View {
        Group {
            if isEditing {
                editingContent
            } else {
                displayContent
            }
        }
        .contentShape(Rectangle())
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
        .contextMenu {
            Button("Edit", systemImage: "pencil") {
                beginEditing()
            }

            Button(item.isCompleted ? "Mark Incomplete" : "Mark Complete", systemImage: item.isCompleted ? "circle" : "checkmark.circle") {
                onToggle()
            }

            Button("Move", systemImage: "arrow.up.arrow.down") {
                onMoveRequested()
            }

            Divider()

            Button("Delete", systemImage: "trash", role: .destructive, action: onDelete)
        }
        .accessibilityAction(named: Text(item.isCompleted ? "Mark incomplete" : "Mark complete")) {
            onToggle()
        }
        .accessibilityAction(named: Text("Edit")) {
            beginEditing()
        }
        .accessibilityAction(named: Text("Move")) {
            onMoveRequested()
        }
        .accessibilityAction(named: Text("Delete")) {
            onDelete()
        }
        .accessibilityIdentifier("checklist-item-\(item.id.uuidString)")
        .onAppear {
            if !isEditing { draftTitle = item.title }
        }
        .onChange(of: isEditing) { _, editing in
            if editing {
                localValidationMessage = nil
                isTitleFocused = true
            } else {
                isTitleFocused = false
            }
        }
    }

    private var displayContent: some View {
        HStack(alignment: .top, spacing: 12) {
            Button(action: onToggle) {
                Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(item.isCompleted ? .secondary : Color.accentColor)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(item.isCompleted ? "Mark \(item.title) incomplete" : "Mark \(item.title) complete")
            .accessibilityValue(item.isCompleted ? "Completed" : "Not completed")

            Button(action: beginEditing) {
                Text(item.title)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .multilineTextAlignment(.leading)
                    .foregroundStyle(item.isCompleted ? .secondary : .primary)
                    .strikethrough(item.isCompleted)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!allowsInlineEditing)
            .accessibilityLabel(item.title)
            .accessibilityHint(allowsInlineEditing ? "Double tap to edit" : "Use the Move action to reorder")
        }
        .padding(.vertical, 3)
    }

    private var editingContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                TextField("Item", text: $draftTitle, axis: .vertical)
                    .lineLimit(1...4)
                    .textFieldStyle(.roundedBorder)
                    .focused($isTitleFocused)
                    .submitLabel(.done)
                    .onSubmit(commitEditing)
                    .accessibilityLabel("Edit item")

                Button(action: commitEditing) {
                    Image(systemName: "checkmark")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .accessibilityLabel("Save item")

                Button(action: cancelEditing) {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .accessibilityLabel("Cancel editing")
            }

            if let localValidationMessage {
                Text(localValidationMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }
        .padding(.vertical, 3)
    }

    private func beginEditing() {
        guard allowsInlineEditing else { return }
        draftTitle = item.title
        localValidationMessage = nil
        isEditing = true
    }

    private func cancelEditing() {
        draftTitle = item.title
        localValidationMessage = nil
        isEditing = false
    }

    private func commitEditing() {
        let normalized: String
        do {
            normalized = try ChecklistInputValidator.itemTitle(draftTitle)
        } catch {
            localValidationMessage = error.localizedDescription
            return
        }

        switch onCommitEdit(normalized) {
        case .success:
            draftTitle = normalized
            localValidationMessage = nil
            isEditing = false
        case .failure(let error):
            onFailure(error)
        }
    }
}
