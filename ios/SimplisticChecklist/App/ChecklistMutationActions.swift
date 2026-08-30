import Foundation

/// UI-facing mutation boundary.
///
/// The SwiftData layer should adapt `ChecklistMutationService` to this small
/// value type at the app root. Views only need the result of a mutation and
/// the stable UUIDs involved; they should not know how a model is persisted.
@MainActor
struct ChecklistMutationActions {
    var createChecklist: (String) -> Result<UUID, Error>
    var renameChecklist: (UUID, String) -> Result<Void, Error>
    var deleteChecklist: (UUID) -> Result<Void, Error>
    var reorderChecklists: ([UUID]) -> Result<Void, Error>

    var addItem: (UUID, String) -> Result<Void, Error>
    var toggleItem: (UUID) -> Result<Void, Error>
    var updateItem: (UUID, String) -> Result<Void, Error>
    var deleteItem: (UUID) -> Result<Void, Error>
    var reorderItems: (UUID, [UUID]) -> Result<Void, Error>
    var clearCompleted: (UUID) -> Result<Void, Error>
    var markAllIncomplete: (UUID) -> Result<Void, Error>

    var canUndo: () -> Bool
    var canRedo: () -> Bool
    var undo: () -> Result<Void, Error>
    var redo: () -> Result<Void, Error>

    init(
        createChecklist: @escaping (String) -> Result<UUID, Error>,
        renameChecklist: @escaping (UUID, String) -> Result<Void, Error>,
        deleteChecklist: @escaping (UUID) -> Result<Void, Error>,
        reorderChecklists: @escaping ([UUID]) -> Result<Void, Error>,
        addItem: @escaping (UUID, String) -> Result<Void, Error>,
        toggleItem: @escaping (UUID) -> Result<Void, Error>,
        updateItem: @escaping (UUID, String) -> Result<Void, Error>,
        deleteItem: @escaping (UUID) -> Result<Void, Error>,
        reorderItems: @escaping (UUID, [UUID]) -> Result<Void, Error>,
        clearCompleted: @escaping (UUID) -> Result<Void, Error>,
        markAllIncomplete: @escaping (UUID) -> Result<Void, Error>,
        canUndo: @escaping () -> Bool,
        canRedo: @escaping () -> Bool,
        undo: @escaping () -> Result<Void, Error>,
        redo: @escaping () -> Result<Void, Error>
    ) {
        self.createChecklist = createChecklist
        self.renameChecklist = renameChecklist
        self.deleteChecklist = deleteChecklist
        self.reorderChecklists = reorderChecklists
        self.addItem = addItem
        self.toggleItem = toggleItem
        self.updateItem = updateItem
        self.deleteItem = deleteItem
        self.reorderItems = reorderItems
        self.clearCompleted = clearCompleted
        self.markAllIncomplete = markAllIncomplete
        self.canUndo = canUndo
        self.canRedo = canRedo
        self.undo = undo
        self.redo = redo
    }
}
