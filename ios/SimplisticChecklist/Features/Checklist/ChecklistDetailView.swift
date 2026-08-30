import SwiftUI

struct ChecklistDetailView: View {
    let checklist: Checklist
    let allChecklists: [Checklist]
    @Binding var selection: UUID?
    let actions: ChecklistMutationActions

    @State private var editMode: EditMode = .inactive
    @State private var showCompleted = true
    @State private var isShowingClearCompletedConfirmation = false
    @State private var isShowingDeleteListConfirmation = false
    @State private var isShowingRename = false
    @State private var mutationError: MutationErrorPresentation?

    private var incompleteItems: [ChecklistItem] {
        checklist.items
            .filter { !$0.isCompleted }
            .sorted(by: Self.itemSort)
    }

    private var completedItems: [ChecklistItem] {
        checklist.items
            .filter(\.isCompleted)
            .sorted(by: Self.itemSort)
    }

    private var hasItems: Bool {
        !checklist.items.isEmpty
    }

    private var hasVisibleItems: Bool {
        !incompleteItems.isEmpty || (showCompleted && !completedItems.isEmpty)
    }

    private var isOrdering: Bool {
        editMode.isEditing
    }

    private var remainingSummary: LocalizedStringKey {
        ChecklistStrings.remaining(incompleteItems.count)
    }

    var body: some View {
        List {
            if hasItems {
                Text(remainingSummary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .accessibilityAddTraits(.isHeader)
            }

            if !hasVisibleItems {
                Section {
                    ChecklistEmptyView(
                        state: hasItems ? .allItemsCompletedButHidden : .noItems,
                        onShowCompleted: hasItems ? { showCompleted = true } : nil
                    )
                    .frame(maxWidth: .infinity)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }
            } else {
                if !incompleteItems.isEmpty {
                    Section("To Do") {
                        ForEach(incompleteItems, id: \.id) { item in
                            itemRow(for: item)
                        }
                        .onMove(perform: moveIncompleteItems)
                    }
                }

                if showCompleted, !completedItems.isEmpty {
                    Section("Completed") {
                        ForEach(completedItems, id: \.id) { item in
                            itemRow(for: item)
                        }
                        .onMove(perform: moveCompletedItems)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .environment(\.editMode, $editMode)
        .navigationTitle(checklist.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                if isOrdering {
                    Button("Done") {
                        withAnimation { editMode = .inactive }
                    }
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button(isOrdering ? "Finish Reordering" : "Edit Order", systemImage: "arrow.up.arrow.down") {
                        withAnimation {
                            editMode = isOrdering ? .inactive : .active
                        }
                    }

                    Button("Rename List", systemImage: "pencil") {
                        isShowingRename = true
                    }
                    .accessibilityIdentifier("rename-list-button")

                    Divider()

                    Toggle(isOn: $showCompleted) {
                        Label("Show Completed", systemImage: "checkmark.circle")
                    }
                    .accessibilityIdentifier("show-completed-toggle")

                    Button("Mark All Incomplete", systemImage: "arrow.uturn.backward.circle") {
                        handle(actions.markAllIncomplete(checklist.id))
                    }
                    .disabled(completedItems.isEmpty)

                    Button("Clear Completed…", systemImage: "trash", role: .destructive) {
                        isShowingClearCompletedConfirmation = true
                    }
                    .disabled(completedItems.isEmpty)
                    .accessibilityIdentifier("clear-completed-button")

                    if allChecklists.count > 1 {
                        Divider()
                        Button("Delete List…", systemImage: "trash", role: .destructive) {
                            isShowingDeleteListConfirmation = true
                        }
                    }

                    if actions.canUndo() {
                        Divider()
                        Button("Undo", systemImage: "arrow.uturn.backward") {
                            handle(actions.undo())
                        }
                    }

                    if actions.canRedo() {
                        Button("Redo", systemImage: "arrow.uturn.forward") {
                            handle(actions.redo())
                        }
                    }
                } label: {
                    Label("List Actions", systemImage: "ellipsis.circle")
                }
                .accessibilityLabel("List actions")
                .accessibilityIdentifier("list-actions-button")
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            ItemComposerView(
                onCommit: { title in
                    actions.addItem(checklist.id, title)
                },
                onFailure: { error in
                    mutationError = MutationErrorPresentation(error: error)
                }
            )
        }
        .sheet(isPresented: $isShowingRename) {
            ListNamePrompt(
                title: "Rename List",
                initialName: checklist.name,
                existingNames: allChecklists
                    .filter { $0.id != checklist.id }
                    .map(\.name)
            ) { name in
                let result = actions.renameChecklist(checklist.id, name)
                if case .failure(let error) = result {
                    mutationError = MutationErrorPresentation(error: error)
                }
                return result
            }
        }
        .confirmationDialog(
            "Clear completed items?",
            isPresented: $isShowingClearCompletedConfirmation
        ) {
            Button("Clear Completed", role: .destructive) {
                handle(actions.clearCompleted(checklist.id))
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Completed items will be removed from this list.")
        }
        .confirmationDialog(
            "Delete this list?",
            isPresented: $isShowingDeleteListConfirmation
        ) {
            Button("Delete List", role: .destructive) {
                let result = actions.deleteChecklist(checklist.id)
                handle(result)
                if case .success = result {
                    selection = nil
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("\"\(checklist.name)\" and all of its items will be deleted.")
        }
        .alert(item: $mutationError) { presentation in
            Alert(
                title: Text("Couldn't save"),
                message: Text(presentation.message),
                dismissButton: .default(Text("OK"))
            )
        }
    }

    @ViewBuilder
    private func itemRow(for item: ChecklistItem) -> some View {
        ChecklistItemRow(
            item: item,
            allowsInlineEditing: !isOrdering,
            onToggle: {
                handle(actions.toggleItem(item.id))
            },
            onCommitEdit: { title in
                let result = actions.updateItem(item.id, title)
                if case .failure(let error) = result {
                    mutationError = MutationErrorPresentation(error: error)
                }
                return result
            },
            onDelete: {
                handle(actions.deleteItem(item.id))
            },
            onMoveRequested: {
                withAnimation { editMode = .active }
            },
            onFailure: { error in
                mutationError = MutationErrorPresentation(error: error)
            }
        )
    }

    private func moveIncompleteItems(from offsets: IndexSet, to destination: Int) {
        moveItems(in: incompleteItems, from: offsets, to: destination)
    }

    private func moveCompletedItems(from offsets: IndexSet, to destination: Int) {
        moveItems(in: completedItems, from: offsets, to: destination)
    }

    private func moveItems(in group: [ChecklistItem], from offsets: IndexSet, to destination: Int) {
        var ids = group.map(\.id)
        ids.move(fromOffsets: offsets, toOffset: destination)
        handle(actions.reorderItems(checklist.id, ids))
    }

    private func handle(_ result: Result<Void, Error>) {
        if case .failure(let error) = result {
            mutationError = MutationErrorPresentation(error: error)
        }
    }

    private static func itemSort(_ lhs: ChecklistItem, _ rhs: ChecklistItem) -> Bool {
        if lhs.sortOrder != rhs.sortOrder {
            return lhs.sortOrder < rhs.sortOrder
        }
        if lhs.createdAt != rhs.createdAt {
            return lhs.createdAt < rhs.createdAt
        }
        return lhs.id.uuidString < rhs.id.uuidString
    }
}

private struct MutationErrorPresentation: Identifiable {
    let id = UUID()
    let message: String

    init(error: Error) {
        let localized = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        message = localized.isEmpty ? "The change could not be saved. Please try again." : localized
    }
}
