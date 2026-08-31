import SwiftUI

struct ListsSidebarView: View {
    let checklists: [Checklist]
    @Binding var selection: UUID?
    let actions: ChecklistMutationActions
    let onChecklistDeleted: (UUID) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var editMode: EditMode = .inactive
    @State private var listPrompt: ListPromptRequest?
    @State private var pendingDelete: DeleteListRequest?
    @State private var isShowingAbout = false
    @State private var mutationError: MutationErrorPresentation?

    private var isEditing: Bool {
        editMode.isEditing
    }

    var body: some View {
        List(selection: $selection) {
            Section {
                ForEach(checklists, id: \.id) { checklist in
                    NavigationLink(value: checklist.id) {
                        ListRowView(checklist: checklist)
                    }
                    .contextMenu {
                        Button("Rename", systemImage: "pencil") {
                            listPrompt = .rename(checklist)
                        }

                        if checklists.count > 1 {
                            Button("Delete", systemImage: "trash", role: .destructive) {
                                requestDelete(checklist)
                            }
                        }
                    }
                }
                .onMove(perform: moveChecklists)
                .onDelete(perform: requestDelete(at:))
            }
        }
        .listStyle(.sidebar)
        .environment(\.editMode, $editMode)
        .navigationTitle("Lists")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                if checklists.count > 1 || isEditing {
                    if isEditing {
                        Button("Done") {
                            setEditMode(.inactive)
                        }
                        .accessibilityLabel("Finish editing lists")
                        .accessibilityIdentifier(ChecklistAccessibility.editListsButton)
                    } else {
                        Button("Edit") {
                            setEditMode(.active)
                        }
                        .accessibilityLabel("Edit lists")
                        .accessibilityIdentifier(ChecklistAccessibility.editListsButton)
                    }
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    listPrompt = .create
                } label: {
                    Label("New List", systemImage: "plus")
                }
                .keyboardShortcut("n", modifiers: .command)
                .accessibilityIdentifier(ChecklistAccessibility.newListButton)
            }

            ToolbarItem(placement: .secondaryAction) {
                Menu {
                    Button("About", systemImage: "info.circle") {
                        isShowingAbout = true
                    }

                    if actions.canUndo() {
                        Divider()
                        Button("Undo", systemImage: "arrow.uturn.backward") {
                            handle(actions.undo())
                        }
                        .keyboardShortcut("z", modifiers: .command)
                    }

                    if actions.canRedo() {
                        Button("Redo", systemImage: "arrow.uturn.forward") {
                            handle(actions.redo())
                        }
                        .keyboardShortcut("z", modifiers: [.command, .shift])
                    }
                } label: {
                    Label("More", systemImage: "ellipsis.circle")
                }
            }
        }
        .sheet(item: $listPrompt) { request in
            switch request.mode {
            case .create:
                ListNamePrompt(title: "New List", existingNames: checklists.map(\.name)) { name in
                    switch actions.createChecklist(name) {
                    case .success(let newID):
                        selection = newID
                        return .success(())
                    case .failure(let error):
                        return .failure(error)
                    }
                }
            case .rename(let checklist):
                ListNamePrompt(
                    title: "Rename List",
                    initialName: checklist.name,
                    existingNames: checklists
                        .filter { $0.id != checklist.id }
                        .map(\.name)
                ) { name in
                    actions.renameChecklist(checklist.id, name)
                }
            }
        }
        .sheet(isPresented: $isShowingAbout) {
            AboutView()
        }
        .confirmationDialog(
            "Delete this list?",
            isPresented: Binding(
                get: { pendingDelete != nil },
                set: { if !$0 { pendingDelete = nil } }
            ),
            presenting: pendingDelete
        ) { request in
            Button("Delete List", role: .destructive) {
                confirmDelete(request)
            }
            Button("Cancel", role: .cancel) {}
        } message: { request in
            Text(ChecklistStrings.deleteListMessage(for: request.name))
        }
        .alert(item: $mutationError) { presentation in
            Alert(
                title: Text("Couldn't Complete Action"),
                message: Text(presentation.message),
                dismissButton: .default(Text("OK"))
            )
        }
    }

    private func moveChecklists(from offsets: IndexSet, to destination: Int) {
        var ids = checklists.map(\.id)
        ids.move(fromOffsets: offsets, toOffset: destination)
        handle(actions.reorderChecklists(ids))
    }

    private func setEditMode(_ mode: EditMode) {
        if reduceMotion {
            editMode = mode
        } else {
            withAnimation { editMode = mode }
        }
    }

    private func requestDelete(at offsets: IndexSet) {
        guard checklists.count > 1, let index = offsets.first else { return }
        requestDelete(checklists[index])
    }

    private func requestDelete(_ checklist: Checklist) {
        guard checklists.count > 1 else { return }
        pendingDelete = DeleteListRequest(id: checklist.id, name: checklist.name)
    }

    private func confirmDelete(_ request: DeleteListRequest) {
        let wasSelected = selection == request.id
        let result = actions.deleteChecklist(request.id)
        if case .success = result, wasSelected {
            onChecklistDeleted(request.id)
        }
        handle(result)

        pendingDelete = nil
    }

    private func handle(_ result: Result<Void, Error>) {
        if case .failure(let error) = result {
            mutationError = MutationErrorPresentation(error: error)
        }
    }
}

private struct ListPromptRequest: Identifiable {
    enum Mode {
        case create
        case rename(Checklist)
    }

    let id = UUID()
    let mode: Mode

    static var create: Self { Self(mode: .create) }

    static func rename(_ checklist: Checklist) -> Self {
        Self(mode: .rename(checklist))
    }
}

private struct DeleteListRequest: Identifiable {
    let id: UUID
    let name: String
}
