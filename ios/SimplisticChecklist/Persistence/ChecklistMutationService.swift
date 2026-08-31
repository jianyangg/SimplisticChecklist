import Foundation
import SwiftData

enum ChecklistMutationError: LocalizedError, Equatable {
    case checklistNotFound
    case itemNotFound
    case cannotDeleteLastChecklist
    case invalidReorder
    case nothingToUndo
    case nothingToRedo
    case persistenceFailed(String)

    var errorDescription: String? {
        switch self {
        case .checklistNotFound:
            String(localized: "This checklist is no longer available.")
        case .itemNotFound:
            String(localized: "This item is no longer available.")
        case .cannotDeleteLastChecklist:
            String(localized: "Keep at least one checklist.")
        case .invalidReorder:
            String(localized: "The order could not be updated.")
        case .nothingToUndo:
            String(localized: "There is nothing to undo.")
        case .nothingToRedo:
            String(localized: "There is nothing to redo.")
        case .persistenceFailed(let message):
            message.isEmpty
                ? String(localized: "The change could not be saved. Please try again.")
                : message
        }
    }
}

@MainActor
final class ChecklistMutationService {
    let context: ModelContext
    private let saveOperation: () throws -> Void
    private var undoStack: [UndoableCommand] = []
    private var redoStack: [UndoableCommand] = []

    init(context: ModelContext, saveOperation: (() throws -> Void)? = nil) {
        self.context = context
        self.saveOperation = saveOperation ?? { try context.save() }

        // SwiftData opens implicit undo groups around context changes. A
        // command also needs to own its save boundary, so layering a second
        // UndoManager group here can merge adjacent commands and can leave a
        // group open after rollback. The service therefore owns a small,
        // snapshot-based history and deliberately disables context undoing.
        // This keeps each successful mutation one command and makes failed
        // undo/redo operations retryable without changing stack semantics.
        context.undoManager = nil
    }

    func canUndo() -> Bool {
        !undoStack.isEmpty
    }

    func canRedo() -> Bool {
        !redoStack.isEmpty
    }

    func undo() throws {
        guard let command = undoStack.last else {
            throw ChecklistMutationError.nothingToUndo
        }

        try restore(command.before)
        undoStack.removeLast()
        redoStack.append(command)
    }

    func redo() throws {
        guard let command = redoStack.last else {
            throw ChecklistMutationError.nothingToRedo
        }

        try restore(command.after)
        redoStack.removeLast()
        undoStack.append(command)
    }

    func createChecklist(named name: String) throws -> UUID {
        try performCommand(actionName: ChecklistActionNames.createList) {
            let existingChecklists = try fetchChecklists()
            let existingNames = existingChecklists.map(\.name)
            let normalized = try ChecklistInputValidator.listName(name, existingNames: existingNames)
            let checklist = Checklist(
                name: normalized,
                sortOrder: (existingChecklists.map(\.sortOrder).max() ?? -1) + 1
            )
            context.insert(checklist)
            return checklist.id
        }
    }

    func renameChecklist(id: UUID, to name: String) throws {
        try performCommand(actionName: ChecklistActionNames.renameList) {
            guard let checklist = try findChecklist(id: id) else {
                throw ChecklistMutationError.checklistNotFound
            }

            let existingNames = try fetchChecklists()
                .filter { $0.id != id }
                .map(\.name)
            checklist.name = try ChecklistInputValidator.listName(name, existingNames: existingNames)
            touch(checklist)
        }
    }

    func deleteChecklist(id: UUID) throws {
        try performCommand(actionName: ChecklistActionNames.deleteList) {
            let checklists = try fetchChecklists()
            guard checklists.count > 1 else {
                throw ChecklistMutationError.cannotDeleteLastChecklist
            }
            guard let checklist = checklists.first(where: { $0.id == id }) else {
                throw ChecklistMutationError.checklistNotFound
            }

            context.delete(checklist)
            normalizeListOrderAndTouch(checklists.filter { $0.id != id })
        }
    }

    func reorderChecklists(ids: [UUID]) throws {
        try performCommand(actionName: ChecklistActionNames.reorderLists) {
            let checklists = try fetchChecklists()
            let byID = Dictionary(uniqueKeysWithValues: checklists.map { ($0.id, $0) })
            guard ids.count == byID.count, Set(ids) == Set(byID.keys) else {
                throw ChecklistMutationError.invalidReorder
            }

            for (index, id) in ids.enumerated() {
                byID[id]?.sortOrder = index
                if let checklist = byID[id] { touch(checklist) }
            }
        }
    }

    func addItem(to checklistID: UUID, title: String) throws {
        try performCommand(actionName: ChecklistActionNames.addItem) {
            guard let checklist = try findChecklist(id: checklistID) else {
                throw ChecklistMutationError.checklistNotFound
            }
            let normalized = try ChecklistInputValidator.itemTitle(title)
            let nextOrder = (checklist.items.map(\.sortOrder).max() ?? -1) + 1
            let item = ChecklistItem(title: normalized, sortOrder: nextOrder)
            context.insert(item)
            checklist.items.append(item)
            item.checklist = checklist
            touch(checklist)
        }
    }

    func addItems(to checklistID: UUID, titles: [String]) throws {
        try performCommand(actionName: ChecklistActionNames.addMultipleItems) {
            guard let checklist = try findChecklist(id: checklistID) else {
                throw ChecklistMutationError.checklistNotFound
            }
            guard !titles.isEmpty else {
                throw ChecklistInputError.emptyItemTitle
            }

            let normalizedTitles = try titles.map(ChecklistInputValidator.itemTitle)
            let firstOrder = (checklist.items.map(\.sortOrder).max() ?? -1) + 1
            for (offset, title) in normalizedTitles.enumerated() {
                let item = ChecklistItem(title: title, sortOrder: firstOrder + offset)
                context.insert(item)
                checklist.items.append(item)
                item.checklist = checklist
            }
            touch(checklist)
        }
    }

    func toggleItem(id: UUID) throws {
        try performCommand(actionName: ChecklistActionNames.toggleItem) {
            guard let item = try findItem(id: id), let checklist = item.checklist else {
                throw ChecklistMutationError.itemNotFound
            }
            item.isCompleted.toggle()
            touch(item)
            touch(checklist)
        }
    }

    func updateItem(id: UUID, title: String) throws {
        try performCommand(actionName: ChecklistActionNames.editItem) {
            guard let item = try findItem(id: id), let checklist = item.checklist else {
                throw ChecklistMutationError.itemNotFound
            }
            item.title = try ChecklistInputValidator.itemTitle(title)
            touch(item)
            touch(checklist)
        }
    }

    func deleteItem(id: UUID) throws {
        try performCommand(actionName: ChecklistActionNames.deleteItem) {
            guard let item = try findItem(id: id), let checklist = item.checklist else {
                throw ChecklistMutationError.itemNotFound
            }
            checklist.items.removeAll { $0.id == item.id }
            context.delete(item)
            normalizeItemOrderAndTouch([checklist])
            touch(checklist)
        }
    }

    func moveItem(id: UUID, to destinationChecklistID: UUID) throws {
        try performCommand(actionName: ChecklistActionNames.moveItem) {
            guard let item = try findItem(id: id),
                  let sourceChecklist = item.checklist else {
                throw ChecklistMutationError.itemNotFound
            }
            guard let destinationChecklist = try findChecklist(id: destinationChecklistID) else {
                throw ChecklistMutationError.checklistNotFound
            }
            guard sourceChecklist.id != destinationChecklist.id else {
                throw ChecklistMutationError.invalidReorder
            }

            let destinationGroup = destinationChecklist.items.filter {
                $0.isCompleted == item.isCompleted
            }
            item.sortOrder = (destinationGroup.map(\.sortOrder).max() ?? -1) + 1
            sourceChecklist.items.removeAll { $0.id == item.id }
            destinationChecklist.items.append(item)
            item.checklist = destinationChecklist

            normalizeItemOrderAndTouch([sourceChecklist, destinationChecklist])
            touch(item)
            touch(sourceChecklist)
            touch(destinationChecklist)
        }
    }

    func reorderItems(in checklistID: UUID, ids: [UUID]) throws {
        try performCommand(actionName: ChecklistActionNames.reorderItems) {
            guard let checklist = try findChecklist(id: checklistID) else {
                throw ChecklistMutationError.checklistNotFound
            }

            let group = checklist.items
                .filter { ids.contains($0.id) }
                .sorted(by: ChecklistOrderer.itemSort)
            let normalizedIDs = ChecklistOrderer.normalizedIDs(ids, from: group)
            guard !group.isEmpty,
                  ids.count == group.count,
                  Set(ids).count == group.count,
                  normalizedIDs.count == group.count else {
                throw ChecklistMutationError.invalidReorder
            }

            let movedIDs = Set(normalizedIDs)
            let movedItems = normalizedIDs.compactMap { id in
                group.first(where: { $0.id == id })
            }
            guard let movedCompletion = movedItems.first?.isCompleted,
                  movedItems.allSatisfy({ $0.isCompleted == movedCompletion }) else {
                throw ChecklistMutationError.invalidReorder
            }

            let untouchedItems = checklist.items
                .filter { !movedIDs.contains($0.id) }
                .sorted(by: ChecklistOrderer.itemSort)
            let orderedItems: [ChecklistItem]
            if movedCompletion {
                orderedItems = untouchedItems.filter { !$0.isCompleted }
                    + movedItems
                    + untouchedItems.filter(\.isCompleted)
            } else {
                orderedItems = movedItems
                    + untouchedItems.filter { !$0.isCompleted }
                    + untouchedItems.filter(\.isCompleted)
            }

            for (index, item) in orderedItems.enumerated() {
                item.sortOrder = index
                touch(item)
            }
            touch(checklist)
        }
    }

    func clearCompleted(in checklistID: UUID) throws {
        try performCommand(actionName: ChecklistActionNames.clearCompleted) {
            guard let checklist = try findChecklist(id: checklistID) else {
                throw ChecklistMutationError.checklistNotFound
            }
            let completedItems = checklist.items.filter(\.isCompleted)
            let completedIDs = Set(completedItems.map(\.id))
            checklist.items.removeAll { completedIDs.contains($0.id) }
            for item in completedItems {
                context.delete(item)
            }
            normalizeItemOrderAndTouch([checklist])
            touch(checklist)
        }
    }

    func markAllIncomplete(in checklistID: UUID) throws {
        try performCommand(actionName: ChecklistActionNames.markAllIncomplete) {
            guard let checklist = try findChecklist(id: checklistID) else {
                throw ChecklistMutationError.checklistNotFound
            }
            for item in checklist.items where item.isCompleted {
                item.isCompleted = false
                touch(item)
            }
            normalizeItemOrderAndTouch([checklist])
            touch(checklist)
        }
    }

    func duplicateChecklist(id: UUID) throws -> UUID {
        try performCommand(actionName: ChecklistActionNames.duplicateList) {
            let checklists = try fetchChecklists()
            guard let source = checklists.first(where: { $0.id == id }) else {
                throw ChecklistMutationError.checklistNotFound
            }

            let name = ChecklistDuplicateNameGenerator.name(
                for: source.name,
                existingNames: checklists.map(\.name)
            )
            let duplicate = Checklist(
                name: name,
                sortOrder: (checklists.map(\.sortOrder).max() ?? -1) + 1
            )
            context.insert(duplicate)

            for (index, sourceItem) in source.items.sorted(by: ChecklistOrderer.itemSort).enumerated() {
                let item = ChecklistItem(
                    title: sourceItem.title,
                    isCompleted: sourceItem.isCompleted,
                    sortOrder: index
                )
                context.insert(item)
                duplicate.items.append(item)
                item.checklist = duplicate
            }
            return duplicate.id
        }
    }

    func fetchChecklists() throws -> [Checklist] {
        try context.fetch(FetchDescriptor<Checklist>()).sorted(by: ChecklistOrderer.checklistSort)
    }

    private func findChecklist(id: UUID) throws -> Checklist? {
        try fetchChecklists().first(where: { $0.id == id })
    }

    private func findItem(id: UUID) throws -> ChecklistItem? {
        let checklists = try fetchChecklists()
        return checklists.lazy.flatMap(\.items).first(where: { $0.id == id })
    }

    private func touch(_ checklist: Checklist) {
        checklist.updatedAt = .now
    }

    private func touch(_ item: ChecklistItem) {
        item.updatedAt = .now
    }

    private func normalizeListOrderAndTouch(_ checklists: [Checklist]) {
        let listOrders = Dictionary(uniqueKeysWithValues: checklists.map { ($0.id, $0.sortOrder) })
        ChecklistOrderer.normalizeChecklists(checklists)

        for checklist in checklists where listOrders[checklist.id] != checklist.sortOrder {
            touch(checklist)
        }
    }

    private func normalizeItemOrderAndTouch(_ checklists: [Checklist]) {
        let itemOrders = Dictionary(
            uniqueKeysWithValues: checklists
                .flatMap(\.items)
                .map { ($0.id, $0.sortOrder) }
        )
        ChecklistOrderer.normalizeItems(in: checklists)

        for item in checklists.flatMap(\.items) where itemOrders[item.id] != item.sortOrder {
            touch(item)
        }
    }

    private func performCommand<T>(
        actionName: LocalizedStringResource,
        mutation: () throws -> T
    ) throws -> T {
        let before = try ChecklistStoreSnapshot(context: context)

        do {
            let result = try mutation()
            let after = try ChecklistStoreSnapshot(context: context)
            try saveExactlyOnce()

            undoStack.append(UndoableCommand(before: before, after: after, actionName: actionName))
            redoStack.removeAll(keepingCapacity: true)
            return result
        } catch {
            context.rollback()
            throw error
        }
    }

    private func restore(_ snapshot: ChecklistStoreSnapshot) throws {
        do {
            try snapshot.apply(to: context)
            try saveExactlyOnce()
        } catch {
            context.rollback()
            throw error
        }
    }

    private func saveExactlyOnce() throws {
        do {
            try saveOperation()
        } catch {
            throw ChecklistMutationError.persistenceFailed(error.localizedDescription)
        }
    }
}

private struct UndoableCommand {
    let before: ChecklistStoreSnapshot
    let after: ChecklistStoreSnapshot
    let actionName: LocalizedStringResource
}

private enum ChecklistActionNames {
    static let addItem = LocalizedStringResource("Add Item", comment: "Undo action for adding a checklist item.")
    static let addMultipleItems = LocalizedStringResource(
        "Add Multiple Items",
        comment: "Undo action for adding several checklist items."
    )
    static let editItem = LocalizedStringResource("Edit Item", comment: "Undo action for editing a checklist item.")
    static let toggleItem = LocalizedStringResource("Change Completion", comment: "Undo action for completing or uncompleting an item.")
    static let deleteItem = LocalizedStringResource("Delete Item", comment: "Undo action for deleting a checklist item.")
    static let moveItem = LocalizedStringResource("Move Item", comment: "Undo action for moving an item to another list.")
    static let reorderItems = LocalizedStringResource("Reorder Items", comment: "Undo action for reordering checklist items.")
    static let clearCompleted = LocalizedStringResource(
        "Clear Completed Items",
        comment: "Undo action for removing completed checklist items."
    )
    static let markAllIncomplete = LocalizedStringResource(
        "Mark All Items Incomplete",
        comment: "Undo action for marking all checklist items incomplete."
    )
    static let createList = LocalizedStringResource("Create List", comment: "Undo action for creating a checklist.")
    static let duplicateList = LocalizedStringResource(
        "Duplicate List",
        comment: "Undo action for duplicating a checklist."
    )
    static let renameList = LocalizedStringResource("Rename List", comment: "Undo action for renaming a checklist.")
    static let deleteList = LocalizedStringResource("Delete List", comment: "Undo action for deleting a checklist.")
    static let reorderLists = LocalizedStringResource("Reorder Lists", comment: "Undo action for reordering checklists.")
}
