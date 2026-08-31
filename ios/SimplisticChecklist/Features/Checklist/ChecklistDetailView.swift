import SwiftUI

struct ChecklistDetailView: View {
    let checklist: Checklist
    let allChecklists: [Checklist]
    @Binding var selection: UUID?
    let actions: ChecklistMutationActions
    let onChecklistDeleted: (UUID) -> Void
    private let displayPreferences: ChecklistDisplayPreferences

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var editMode: EditMode = .inactive
    @State private var showCompleted: Bool
    @State private var isShowingBulkEntry = false
    @State private var isShowingClearCompletedConfirmation = false
    @State private var isShowingDeleteListConfirmation = false
    @State private var isShowingRename = false
    @State private var mutationError: MutationErrorPresentation?

    init(
        checklist: Checklist,
        allChecklists: [Checklist],
        selection: Binding<UUID?>,
        actions: ChecklistMutationActions,
        onChecklistDeleted: @escaping (UUID) -> Void
    ) {
        self.checklist = checklist
        self.allChecklists = allChecklists
        _selection = selection
        self.actions = actions
        self.onChecklistDeleted = onChecklistDeleted

        let preferences = ChecklistDisplayPreferences(
            defaults: ChecklistLaunchConfiguration.selectionStore
        )
        displayPreferences = preferences
        _showCompleted = State(
            initialValue: preferences.showsCompleted(for: checklist.id)
        )
    }

    private var incompleteItems: [ChecklistItem] {
        checklist.items
            .filter { !$0.isCompleted }
            .sorted(by: ChecklistOrderer.itemSort)
    }

    private var completedItems: [ChecklistItem] {
        checklist.items
            .filter(\.isCompleted)
            .sorted(by: ChecklistOrderer.itemSort)
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

    private var canReorderItems: Bool {
        incompleteItems.count > 1 || (showCompleted && completedItems.count > 1)
    }

    private var remainingSummary: LocalizedStringKey {
        incompleteItems.isEmpty
            ? ChecklistStrings.allItemsComplete
            : ChecklistStrings.remaining(incompleteItems.count)
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
                        setEditMode(.inactive)
                    }
                    .accessibilityIdentifier(ChecklistAccessibility.detailDoneButton)
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    if canReorderItems || isOrdering {
                        if isOrdering {
                            Button("Finish Reordering", systemImage: "arrow.up.arrow.down") {
                                setEditMode(.inactive)
                            }
                            .accessibilityIdentifier(ChecklistAccessibility.editOrderButton)
                        } else {
                            Button("Edit Order", systemImage: "arrow.up.arrow.down") {
                                setEditMode(.active)
                            }
                            .accessibilityIdentifier(ChecklistAccessibility.editOrderButton)
                        }
                    }

                    Button("Rename List", systemImage: "pencil") {
                        isShowingRename = true
                    }
                    .accessibilityIdentifier(ChecklistAccessibility.renameListButton)

                    Button("Add Multiple Items…", systemImage: "text.badge.plus") {
                        isShowingBulkEntry = true
                    }
                    .accessibilityIdentifier(ChecklistAccessibility.addMultipleItemsButton)

                    Button("Duplicate List", systemImage: "plus.square.on.square") {
                        switch actions.duplicateChecklist(checklist.id) {
                        case .success(let duplicateID):
                            selection = duplicateID
                        case .failure(let error):
                            mutationError = MutationErrorPresentation(error: error)
                        }
                    }
                    .accessibilityIdentifier(ChecklistAccessibility.duplicateListButton)

                    ShareLink(item: ChecklistTextExporter.text(for: checklist)) {
                        Label("Share List", systemImage: "square.and.arrow.up")
                    }
                    .accessibilityIdentifier(ChecklistAccessibility.shareListButton)

                    if !completedItems.isEmpty {
                        Divider()

                        Toggle(isOn: $showCompleted) {
                            Label("Show Completed", systemImage: "checkmark.circle")
                        }
                        .accessibilityIdentifier(ChecklistAccessibility.showCompletedToggle)

                        Button("Mark All Incomplete", systemImage: "arrow.uturn.backward.circle") {
                            handle(actions.markAllIncomplete(checklist.id))
                        }
                        .accessibilityIdentifier(ChecklistAccessibility.markAllIncompleteButton)

                        Button("Clear Completed…", systemImage: "trash", role: .destructive) {
                            isShowingClearCompletedConfirmation = true
                        }
                        .accessibilityIdentifier(ChecklistAccessibility.clearCompletedButton)
                    }

                    if allChecklists.count > 1 {
                        Divider()
                        Button("Delete List…", systemImage: "trash", role: .destructive) {
                            isShowingDeleteListConfirmation = true
                        }
                        .accessibilityIdentifier(ChecklistAccessibility.deleteListButton)
                    }

                    if actions.canUndo() {
                        Divider()
                        Button("Undo", systemImage: "arrow.uturn.backward") {
                            handle(actions.undo())
                        }
                        .keyboardShortcut("z", modifiers: .command)
                        .accessibilityIdentifier(ChecklistAccessibility.undoButton)
                    }

                    if actions.canRedo() {
                        Button("Redo", systemImage: "arrow.uturn.forward") {
                            handle(actions.redo())
                        }
                        .keyboardShortcut("z", modifiers: [.command, .shift])
                        .accessibilityIdentifier(ChecklistAccessibility.redoButton)
                    }
                } label: {
                    Label("List Actions", systemImage: "ellipsis.circle")
                }
                .accessibilityLabel("List actions")
                .accessibilityIdentifier(ChecklistAccessibility.listActionsButton)
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
                actions.renameChecklist(checklist.id, name)
            }
        }
        .sheet(isPresented: $isShowingBulkEntry) {
            BulkItemEntryView { titles in
                actions.addItems(checklist.id, titles)
            }
        }
        .onChange(of: showCompleted) { _, newValue in
            displayPreferences.setShowsCompleted(newValue, for: checklist.id)
        }
        .confirmationDialog(
            "Clear completed items?",
            isPresented: $isShowingClearCompletedConfirmation
        ) {
            Button("Clear Completed", role: .destructive) {
                handle(actions.clearCompleted(checklist.id))
            }
            .accessibilityIdentifier(ChecklistAccessibility.clearCompletedConfirmationButton)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Completed items will be removed from this list.")
        }
        .confirmationDialog(
            "Delete this list?",
            isPresented: $isShowingDeleteListConfirmation
        ) {
            Button("Delete List", role: .destructive) {
                let wasSelected = selection == checklist.id
                let result = actions.deleteChecklist(checklist.id)
                if case .success = result, wasSelected {
                    onChecklistDeleted(checklist.id)
                }
                handle(result)
            }
            .accessibilityIdentifier(ChecklistAccessibility.deleteListConfirmationButton)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(ChecklistStrings.deleteListMessage(for: checklist.name))
        }
        .alert(item: $mutationError) { presentation in
            Alert(
                title: Text("Couldn't Complete Action"),
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
                actions.updateItem(item.id, title)
            },
            onDelete: {
                handle(actions.deleteItem(item.id))
            },
            moveDestinations: isOrdering
                ? []
                : allChecklists
                    .filter { $0.id != checklist.id }
                    .sorted(by: ChecklistOrderer.checklistSort)
                    .map { ChecklistMoveDestination(id: $0.id, name: $0.name) },
            onMoveToChecklist: { destinationID in
                handle(actions.moveItem(item.id, destinationID))
            },
            allowsReordering: canReorderItems && !isOrdering,
            onMoveRequested: {
                setEditMode(.active)
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

    private func setEditMode(_ mode: EditMode) {
        if reduceMotion {
            editMode = mode
        } else {
            withAnimation { editMode = mode }
        }
    }

    private func handle(_ result: Result<Void, Error>) {
        if case .failure(let error) = result {
            mutationError = MutationErrorPresentation(error: error)
        }
    }

}
