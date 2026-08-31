import SwiftUI

struct ChecklistItemRow: View {
    let item: ChecklistItem
    let allowsInlineEditing: Bool
    let onToggle: () -> Void
    let onCommitEdit: (String) -> Result<Void, Error>
    let onDelete: () -> Void
    let moveDestinations: [ChecklistMoveDestination]
    let onMoveToChecklist: (UUID) -> Void
    let allowsReordering: Bool
    let onMoveRequested: () -> Void
    let onFailure: (Error) -> Void

    @FocusState private var isTitleFocused: Bool
    @State private var draftTitle: String
    @State private var isEditing = false
    @State private var localValidationMessage: String?
    @State private var isShowingMoveDestinations = false

    init(
        item: ChecklistItem,
        allowsInlineEditing: Bool = true,
        onToggle: @escaping () -> Void,
        onCommitEdit: @escaping (String) -> Result<Void, Error>,
        onDelete: @escaping () -> Void,
        moveDestinations: [ChecklistMoveDestination] = [],
        onMoveToChecklist: @escaping (UUID) -> Void = { _ in },
        allowsReordering: Bool = true,
        onMoveRequested: @escaping () -> Void = {},
        onFailure: @escaping (Error) -> Void = { _ in }
    ) {
        self.item = item
        self.allowsInlineEditing = allowsInlineEditing
        self.onToggle = onToggle
        self.onCommitEdit = onCommitEdit
        self.onDelete = onDelete
        self.moveDestinations = moveDestinations
        self.onMoveToChecklist = onMoveToChecklist
        self.allowsReordering = allowsReordering
        self.onMoveRequested = onMoveRequested
        self.onFailure = onFailure
        _draftTitle = State(initialValue: item.title)
    }

    @ViewBuilder
    var body: some View {
        if moveDestinations.isEmpty || isEditing {
            accessibleContent
        } else {
            accessibleContent
                .accessibilityAction(named: Text("Move to List")) {
                    isShowingMoveDestinations = true
                }
                .confirmationDialog(
                    "Move to List",
                    isPresented: $isShowingMoveDestinations
                ) {
                    ForEach(moveDestinations) { destination in
                        Button {
                            onMoveToChecklist(destination.id)
                        } label: {
                            Text(verbatim: destination.name)
                        }
                    }
                    Button("Cancel", role: .cancel) {}
                }
        }
    }

    @ViewBuilder
    private var accessibleContent: some View {
        if !isEditing, allowsInlineEditing, allowsReordering {
            commonContent
                .accessibilityAction(named: Text("Edit")) {
                    beginEditing()
                }
                .accessibilityAction(named: Text("Reorder")) {
                    onMoveRequested()
                }
        } else if !isEditing, allowsInlineEditing {
            commonContent
                .accessibilityAction(named: Text("Edit")) {
                    beginEditing()
                }
        } else if !isEditing, allowsReordering {
            commonContent
                .accessibilityAction(named: Text("Reorder")) {
                    onMoveRequested()
                }
        } else {
            commonContent
        }
    }

    @ViewBuilder
    private var commonContent: some View {
        if isEditing {
            baseContent
        } else {
            baseContent
                .accessibilityAction(named: completionAccessibilityActionName) {
                    onToggle()
                }
                .accessibilityAction(named: Text("Delete")) {
                    onDelete()
                }
        }
    }

    private var baseContent: some View {
        VStack(spacing: 0) {
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
            if allowsInlineEditing, !isEditing {
                Button("Edit", systemImage: "pencil") {
                    beginEditing()
                }
            }

            if item.isCompleted {
                Button("Mark Incomplete", systemImage: "circle", action: onToggle)
            } else {
                Button("Mark Complete", systemImage: "checkmark.circle", action: onToggle)
            }

            if !moveDestinations.isEmpty, !isEditing {
                Menu("Move to List", systemImage: "folder") {
                    ForEach(moveDestinations) { destination in
                        Button {
                            onMoveToChecklist(destination.id)
                        } label: {
                            Text(verbatim: destination.name)
                        }
                    }
                }
            }

            if allowsReordering, !isEditing {
                Button("Reorder", systemImage: "arrow.up.arrow.down") {
                    onMoveRequested()
                }
            }

            Divider()

            Button("Delete", systemImage: "trash", role: .destructive, action: onDelete)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(ChecklistAccessibility.checklistItem(item.id))
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
            .accessibilityLabel(ChecklistStrings.itemCompletionLabel(for: item.title, isCompleted: item.isCompleted))
            .accessibilityValue(completionAccessibilityValue)

            titleContent
        }
        .padding(.vertical, 3)
    }

    @ViewBuilder
    private var titleContent: some View {
        if allowsInlineEditing {
            Button(action: beginEditing) {
                itemTitleLabel
            }
            .buttonStyle(.plain)
            .accessibilityLabel(item.title)
            .accessibilityHint(titleAccessibilityHint)
        } else {
            // Keep the title as a draggable, non-button row body while list
            // edit mode is active. A disabled nested Button can prevent the
            // system List reorder gesture from receiving the touch.
            itemTitleLabel
                .accessibilityLabel(item.title)
                .accessibilityHint(titleAccessibilityHint)
        }
    }

    private var itemTitleLabel: some View {
        Text(item.title)
            .frame(maxWidth: .infinity, alignment: .leading)
            .multilineTextAlignment(.leading)
            .foregroundStyle(item.isCompleted ? .secondary : .primary)
            .strikethrough(item.isCompleted)
            .contentShape(Rectangle())
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

    private var completionAccessibilityActionName: Text {
        item.isCompleted ? Text("Mark incomplete") : Text("Mark complete")
    }

    private var completionAccessibilityValue: Text {
        item.isCompleted ? Text("Completed") : Text("Not completed")
    }

    private var titleAccessibilityHint: Text {
        if allowsInlineEditing {
            return Text("Double tap to edit")
        }
        if allowsReordering {
            return Text("Use the Reorder action to reorder")
        }
        return Text("Use the item actions")
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
