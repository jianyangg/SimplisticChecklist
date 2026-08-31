import SwiftUI
import SwiftData

struct AppRootView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [
        SortDescriptor(\Checklist.sortOrder),
        SortDescriptor(\Checklist.createdAt)
    ]) private var checklists: [Checklist]

    @AppStorage(
        LegacyPreferenceKeys.nativeSelectedChecklistID,
        store: ChecklistLaunchConfiguration.selectionStore
    )
    private var selectedChecklistValue = ""

    @State private var launchState: LaunchState = .loading
    @State private var mutationService: ChecklistMutationService?
    @State private var selection: UUID?

    var body: some View {
        Group {
            switch launchState {
            case .loading:
                ProgressView("Loading checklists…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .ready:
                if let mutationService {
                    ChecklistWorkspaceView(
                        checklists: checklists,
                        selection: $selection,
                        actions: makeActions(for: mutationService)
                    )
                } else {
                    ProgressView("Opening checklists…")
                }
            case .failed(let message):
                ContentUnavailableView {
                    Label("Couldn’t Open Checklists", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(message)
                } actions: {
                    Button("Retry") {
                        launchState = .loading
                    }
                }
            }
        }
        .task(id: launchState) {
            guard launchState == .loading else { return }
            bootstrap()
        }
        .onChange(of: selection) { _, newSelection in
            guard let newSelection else { return }
            selectedChecklistValue = newSelection.uuidString
        }
        .onChange(of: checklists.map(\.id)) { _, _ in
            selection = ChecklistSelectionResolver.resolve(
                preferred: selection,
                in: checklists
            )
        }
    }

    private func bootstrap() {
        do {
            let migrator = LegacyChecklistMigrator(
                context: modelContext,
                defaults: migrationDefaults()
            )
            let result = try migrator.migrateIfNeeded()
            let service = ChecklistMutationService(context: modelContext)
            mutationService = service
            let persistedChecklists = try service.fetchChecklists()

            let storedID = UUID(uuidString: selectedChecklistValue)
            let preferredID = storedID ?? result.selectedChecklistID
            selection = ChecklistSelectionResolver.resolve(
                preferred: preferredID,
                in: persistedChecklists
            )
            if let selection {
                selectedChecklistValue = selection.uuidString
            }
            launchState = .ready
        } catch {
            launchState = .failed(error.localizedDescription)
        }
    }

    private func migrationDefaults() -> UserDefaults {
        guard ChecklistLaunchConfiguration.isUITesting else {
            return .standard
        }

        let suiteName = ChecklistLaunchConfiguration.uiTestingDefaultsSuite
        let defaults = ChecklistLaunchConfiguration.selectionStore
        if ChecklistLaunchConfiguration.isSeededLegacy {
            LegacyUITestFixture.seed(into: defaults)
        } else if ChecklistLaunchConfiguration.isFreshInMemory
                    || ChecklistLaunchConfiguration.resetsPersistentStore {
            defaults.removePersistentDomain(forName: suiteName)
        }
        return defaults
    }

    @MainActor
    private func makeActions(for service: ChecklistMutationService) -> ChecklistMutationActions {
        ChecklistMutationActions(
            createChecklist: { name in
                do { return .success(try service.createChecklist(named: name)) }
                catch { return .failure(error) }
            },
            renameChecklist: { id, name in
                do { try service.renameChecklist(id: id, to: name); return .success(()) }
                catch { return .failure(error) }
            },
            deleteChecklist: { id in
                do { try service.deleteChecklist(id: id); return .success(()) }
                catch { return .failure(error) }
            },
            reorderChecklists: { ids in
                do { try service.reorderChecklists(ids: ids); return .success(()) }
                catch { return .failure(error) }
            },
            addItem: { id, title in
                do { try service.addItem(to: id, title: title); return .success(()) }
                catch { return .failure(error) }
            },
            addItems: { id, titles in
                do { try service.addItems(to: id, titles: titles); return .success(()) }
                catch { return .failure(error) }
            },
            toggleItem: { id in
                do { try service.toggleItem(id: id); return .success(()) }
                catch { return .failure(error) }
            },
            updateItem: { id, title in
                do { try service.updateItem(id: id, title: title); return .success(()) }
                catch { return .failure(error) }
            },
            deleteItem: { id in
                do { try service.deleteItem(id: id); return .success(()) }
                catch { return .failure(error) }
            },
            moveItem: { itemID, checklistID in
                do { try service.moveItem(id: itemID, to: checklistID); return .success(()) }
                catch { return .failure(error) }
            },
            reorderItems: { id, ids in
                do { try service.reorderItems(in: id, ids: ids); return .success(()) }
                catch { return .failure(error) }
            },
            clearCompleted: { id in
                do { try service.clearCompleted(in: id); return .success(()) }
                catch { return .failure(error) }
            },
            markAllIncomplete: { id in
                do { try service.markAllIncomplete(in: id); return .success(()) }
                catch { return .failure(error) }
            },
            duplicateChecklist: { id in
                do { return .success(try service.duplicateChecklist(id: id)) }
                catch { return .failure(error) }
            },
            canUndo: { service.canUndo() },
            canRedo: { service.canRedo() },
            undo: {
                do { try service.undo(); return .success(()) }
                catch { return .failure(error) }
            },
            redo: {
                do { try service.redo(); return .success(()) }
                catch { return .failure(error) }
            }
        )
    }
}

private enum LaunchState: Equatable {
    case loading
    case ready
    case failed(String)
}
