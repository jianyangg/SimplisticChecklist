import Foundation

/// Stable identifiers shared by production views and UI-test documentation.
/// Dynamic identifiers are derived only from persisted UUIDs, never from user
/// authored names, so renaming a list does not invalidate automation.
enum ChecklistAccessibility {
    static let newListButton = "new-list-button"
    static let listActionsButton = "list-actions-button"
    static let renameListButton = "rename-list-button"
    static let showCompletedToggle = "show-completed-toggle"
    static let clearCompletedButton = "clear-completed-button"
    static let clearCompletedConfirmationButton = "clear-completed-confirmation-button"
    static let markAllIncompleteButton = "mark-all-incomplete-button"
    static let deleteListButton = "delete-list-button"
    static let deleteListConfirmationButton = "delete-list-confirmation-button"
    static let editOrderButton = "edit-order-button"
    static let detailDoneButton = "detail-done-button"
    static let undoButton = "undo-button"
    static let redoButton = "redo-button"
    static let editListsButton = "edit-lists-button"
    static let addMultipleItemsButton = "add-multiple-items-button"
    static let duplicateListButton = "duplicate-list-button"
    static let shareListButton = "share-list-button"
    static let bulkItemEditor = "bulk-item-editor"
    static let bulkItemAddButton = "bulk-item-add-button"
    static let itemComposerField = "item-composer-field"
    static let itemComposerAddButton = "item-composer-add-button"
    static let listNameField = "list-name-field"
    static let cancelListButton = "cancel-list-button"
    static let saveListButton = "save-list-button"

    static func checklistRow(_ id: UUID) -> String {
        "checklist-row-\(id.uuidString)"
    }

    static func checklistItem(_ id: UUID) -> String {
        "checklist-item-\(id.uuidString)"
    }
}
