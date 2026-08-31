import SwiftUI

/// The native checklist workflow. The app root owns the SwiftData query and
/// selected UUID, then injects the mutation adapter here.
struct ChecklistWorkspaceView: View {
    let checklists: [Checklist]
    @Binding var selection: UUID?
    let actions: ChecklistMutationActions

    @State private var pendingSelectionRestore: SelectionRestore?

    private var sortedChecklists: [Checklist] {
        checklists.sorted(by: ChecklistOrderer.checklistSort)
    }

    private var selectedChecklist: Checklist? {
        guard let selection else { return nil }
        return checklists.first(where: { $0.id == selection })
    }

    var body: some View {
        NavigationSplitView {
            ListsSidebarView(
                checklists: sortedChecklists,
                selection: $selection,
                actions: actions,
                onChecklistDeleted: rememberDeletedChecklist
            )
        } detail: {
            if let selectedChecklist {
                ChecklistDetailView(
                    checklist: selectedChecklist,
                    allChecklists: sortedChecklists,
                    selection: $selection,
                    actions: actions,
                    onChecklistDeleted: rememberDeletedChecklist
                )
                // Reset detail-local draft, filter, edit, and confirmation
                // state when the selected checklist changes.
                .id(selectedChecklist.id)
            } else {
                NoChecklistSelectedView()
            }
        }
        .navigationSplitViewStyle(.balanced)
        .onAppear(perform: resolveSelection)
        .onChange(of: checklists.map(\.id)) { oldIDs, newIDs in
            if let selected = selection,
               oldIDs.contains(selected),
               !newIDs.contains(selected) {
                pendingSelectionRestore = SelectionRestore(
                    deletedID: selected,
                    fallbackID: ChecklistSelectionResolver.resolve(
                        preferred: nil,
                        in: sortedChecklists
                    )
                )
            }

            if let pendingSelectionRestore,
               newIDs.contains(pendingSelectionRestore.deletedID) {
                if selection == pendingSelectionRestore.fallbackID || selection == nil {
                    selection = pendingSelectionRestore.deletedID
                }
                self.pendingSelectionRestore = nil
            } else {
                resolveSelection()
            }
        }
    }

    private func rememberDeletedChecklist(_ id: UUID) {
        let remaining = sortedChecklists.filter { $0.id != id }
        let fallbackID = ChecklistSelectionResolver.resolve(
            preferred: nil,
            in: remaining
        )
        pendingSelectionRestore = SelectionRestore(
            deletedID: id,
            fallbackID: fallbackID
        )
        selection = fallbackID
    }

    private func resolveSelection() {
        selection = ChecklistSelectionResolver.resolve(
            preferred: selection,
            in: sortedChecklists
        )
    }
}

private struct SelectionRestore {
    let deletedID: UUID
    let fallbackID: UUID?
}

private struct NoChecklistSelectedView: View {
    var body: some View {
        ContentUnavailableView {
            Label("No Checklist Selected", systemImage: "checklist")
        } description: {
            Text("Choose a list to see its items.")
        }
    }
}
