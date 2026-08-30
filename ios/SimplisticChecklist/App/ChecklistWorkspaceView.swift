import SwiftUI

/// The native checklist workflow. The app root owns the SwiftData query and
/// selected UUID, then injects the mutation adapter here.
struct ChecklistWorkspaceView: View {
    let checklists: [Checklist]
    @Binding var selection: UUID?
    let actions: ChecklistMutationActions

    private var sortedChecklists: [Checklist] {
        checklists.sorted(by: Self.listSort)
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
                actions: actions
            )
        } detail: {
            if let selectedChecklist {
                ChecklistDetailView(
                    checklist: selectedChecklist,
                    allChecklists: sortedChecklists,
                    selection: $selection,
                    actions: actions
                )
            } else {
                NoChecklistSelectedView()
            }
        }
        .navigationSplitViewStyle(.balanced)
        .onAppear(perform: resolveSelection)
        .onChange(of: checklists.map(\.id)) { _, _ in
            resolveSelection()
        }
    }

    private func resolveSelection() {
        guard !sortedChecklists.isEmpty else {
            selection = nil
            return
        }

        if let selection, sortedChecklists.contains(where: { $0.id == selection }) {
            return
        }

        selection = sortedChecklists[0].id
    }

    private static func listSort(_ lhs: Checklist, _ rhs: Checklist) -> Bool {
        if lhs.sortOrder != rhs.sortOrder {
            return lhs.sortOrder < rhs.sortOrder
        }
        if lhs.createdAt != rhs.createdAt {
            return lhs.createdAt < rhs.createdAt
        }
        return lhs.id.uuidString < rhs.id.uuidString
    }
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
