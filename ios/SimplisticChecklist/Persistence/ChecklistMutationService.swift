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
            "This checklist is no longer available."
        case .itemNotFound:
            "This item is no longer available."
        case .cannotDeleteLastChecklist:
            "Keep at least one checklist."
        case .invalidReorder:
            "The order could not be updated."
        case .nothingToUndo:
            "There is nothing to undo."
        case .nothingToRedo:
            "There is nothing to redo."
        case .persistenceFailed(let message):
            message.isEmpty ? "The change could not be saved. Please try again." : message
        }
    }
}

@MainActor
final class ChecklistMutationService {
    let context: ModelContext

    init(context: ModelContext) {
        self.context = context
        if context.undoManager == nil {
            context.undoManager = UndoManager()
        }
    }

    func canUndo() -> Bool {
        context.undoManager?.canUndo == true
    }

    func canRedo() -> Bool {
        context.undoManager?.canRedo == true
    }

    func undo() throws {
        guard let manager = context.undoManager, manager.canUndo else {
            throw ChecklistMutationError.nothingToUndo
        }
        manager.undo()
        try commit(actionName: nil)
    }

    func redo() throws {
        guard let manager = context.undoManager, manager.canRedo else {
            throw ChecklistMutationError.nothingToRedo
        }
        manager.redo()
        try commit(actionName: nil)
    }

    func createChecklist(named name: String) throws -> UUID {
        let existingNames = try fetchChecklists().map(\.name)
        let normalized = try ChecklistInputValidator.listName(name, existingNames: existingNames)
        let checklist = Checklist(
            name: normalized,
            sortOrder: try fetchChecklists().count
        )
        context.insert(checklist)
        try commit(actionName: "Create Checklist")
        return checklist.id
    }

    func renameChecklist(id: UUID, to name: String) throws {
        guard let checklist = try findChecklist(id: id) else {
            throw ChecklistMutationError.checklistNotFound
        }

        let existingNames = try fetchChecklists()
            .filter { $0.id != id }
            .map(\.name)
        checklist.name = try ChecklistInputValidator.listName(name, existingNames: existingNames)
        touch(checklist)
        try commit(actionName: "Rename Checklist")
    }

    func deleteChecklist(id: UUID) throws {
        let checklists = try fetchChecklists()
        guard checklists.count > 1 else {
            throw ChecklistMutationError.cannotDeleteLastChecklist
        }
        guard let checklist = checklists.first(where: { $0.id == id }) else {
            throw ChecklistMutationError.checklistNotFound
        }

        context.delete(checklist)
        ChecklistOrderer.normalize(checklists.filter { $0.id != id })
        try commit(actionName: "Delete Checklist")
    }

    func reorderChecklists(ids: [UUID]) throws {
        let checklists = try fetchChecklists()
        let byID = Dictionary(uniqueKeysWithValues: checklists.map { ($0.id, $0) })
        guard ids.count == byID.count, Set(ids) == Set(byID.keys) else {
            throw ChecklistMutationError.invalidReorder
        }

        for (index, id) in ids.enumerated() {
            byID[id]?.sortOrder = index
            if let checklist = byID[id] { touch(checklist) }
        }
        try commit(actionName: "Reorder Checklists")
    }

    func addItem(to checklistID: UUID, title: String) throws {
        guard let checklist = try findChecklist(id: checklistID) else {
            throw ChecklistMutationError.checklistNotFound
        }
        let normalized = try ChecklistInputValidator.itemTitle(title)
        let nextOrder = (checklist.items.map(\.sortOrder).max() ?? -1) + 1
        let item = ChecklistItem(title: normalized, sortOrder: nextOrder)
        context.insert(item)
        checklist.items.append(item)
        touch(checklist)
        try commit(actionName: "Add Item")
    }

    func toggleItem(id: UUID) throws {
        guard let item = try findItem(id: id), let checklist = item.checklist else {
            throw ChecklistMutationError.itemNotFound
        }
        item.isCompleted.toggle()
        touch(item)
        touch(checklist)
        try commit(actionName: item.isCompleted ? "Complete Item" : "Mark Item Incomplete")
    }

    func updateItem(id: UUID, title: String) throws {
        guard let item = try findItem(id: id), let checklist = item.checklist else {
            throw ChecklistMutationError.itemNotFound
        }
        item.title = try ChecklistInputValidator.itemTitle(title)
        touch(item)
        touch(checklist)
        try commit(actionName: "Edit Item")
    }

    func deleteItem(id: UUID) throws {
        guard let item = try findItem(id: id), let checklist = item.checklist else {
            throw ChecklistMutationError.itemNotFound
        }
        context.delete(item)
        touch(checklist)
        try commit(actionName: "Delete Item")
    }

    func reorderItems(in checklistID: UUID, ids: [UUID]) throws {
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
        try commit(actionName: "Reorder Items")
    }

    func clearCompleted(in checklistID: UUID) throws {
        guard let checklist = try findChecklist(id: checklistID) else {
            throw ChecklistMutationError.checklistNotFound
        }
        for item in checklist.items.filter(\.isCompleted) {
            context.delete(item)
        }
        touch(checklist)
        try commit(actionName: "Clear Completed Items")
    }

    func markAllIncomplete(in checklistID: UUID) throws {
        guard let checklist = try findChecklist(id: checklistID) else {
            throw ChecklistMutationError.checklistNotFound
        }
        for item in checklist.items where item.isCompleted {
            item.isCompleted = false
            touch(item)
        }
        touch(checklist)
        try commit(actionName: "Mark All Items Incomplete")
    }

    func fetchChecklists() throws -> [Checklist] {
        try context.fetch(FetchDescriptor<Checklist>()).sorted(by: ChecklistOrderer.checklistSort)
    }

    func save() throws {
        try commit(actionName: nil)
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

    private func commit(actionName: String?) throws {
        do {
            try context.save()
            if let actionName {
                context.undoManager?.setActionName(actionName)
            }
        } catch {
            context.rollback()
            throw ChecklistMutationError.persistenceFailed(error.localizedDescription)
        }
    }
}
