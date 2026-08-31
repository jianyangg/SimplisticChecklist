import Foundation
import SwiftData
import Testing
@testable import SimplisticChecklist

@MainActor
@Suite("Checklist persistence mutations")
struct ChecklistMutationServiceTests {
    @Test("saves each successful command exactly once")
    func savesEachCommandExactlyOnce() throws {
        let container = try ModelContainerFactory.makeInMemory()
        let probe = SaveProbe(context: container.mainContext)
        let service = ChecklistMutationService(
            context: container.mainContext,
            saveOperation: { try probe.save() }
        )

        let checklistID = try service.createChecklist(named: "Work")
        #expect(probe.count == 1)

        probe.resetCount()
        try service.addItem(to: checklistID, title: "One")
        #expect(probe.count == 1)

        let itemID = try #require(service.fetchChecklists().first?.items.first?.id)
        probe.resetCount()
        try service.toggleItem(id: itemID)
        #expect(probe.count == 1)

        probe.resetCount()
        try service.undo()
        #expect(probe.count == 1)
        #expect(try service.fetchChecklists().first?.items.first?.isCompleted == false)

        probe.resetCount()
        try service.redo()
        #expect(probe.count == 1)
        #expect(try service.fetchChecklists().first?.items.first?.isCompleted == true)

        probe.resetCount()
        try service.updateItem(id: itemID, title: "Edited")
        #expect(probe.count == 1)

        probe.resetCount()
        try service.reorderItems(in: checklistID, ids: [itemID])
        #expect(probe.count == 1)

        probe.resetCount()
        try service.markAllIncomplete(in: checklistID)
        #expect(probe.count == 1)

        probe.resetCount()
        try service.toggleItem(id: itemID)
        #expect(probe.count == 1)

        probe.resetCount()
        try service.clearCompleted(in: checklistID)
        #expect(probe.count == 1)

        probe.resetCount()
        let secondChecklistID = try service.createChecklist(named: "Personal")
        #expect(probe.count == 1)

        probe.resetCount()
        try service.renameChecklist(id: secondChecklistID, to: "Home")
        #expect(probe.count == 1)

        probe.resetCount()
        try service.reorderChecklists(ids: [secondChecklistID, checklistID])
        #expect(probe.count == 1)

        probe.resetCount()
        try service.deleteChecklist(id: checklistID)
        #expect(probe.count == 1)
    }

    @Test("adds multiple items as one saved and undoable command")
    func addsMultipleItemsAtomically() throws {
        let container = try ModelContainerFactory.makeInMemory()
        let probe = SaveProbe(context: container.mainContext)
        let service = ChecklistMutationService(
            context: container.mainContext,
            saveOperation: { try probe.save() }
        )
        let checklistID = try service.createChecklist(named: "Trip")
        probe.resetCount()

        try service.addItems(to: checklistID, titles: ["Passport", "Book hotel", "Call bank"])

        #expect(probe.count == 1)
        let after = try ChecklistStoreSnapshot(context: container.mainContext)
        #expect(try service.fetchChecklists().first?.items.sorted(by: ChecklistOrderer.itemSort).map(\.title) == [
            "Passport", "Book hotel", "Call bank"
        ])

        probe.resetCount()
        try service.undo()
        #expect(probe.count == 1)
        #expect(try service.fetchChecklists().first?.items.isEmpty == true)

        probe.resetCount()
        try service.redo()
        #expect(probe.count == 1)
        #expect(try ChecklistStoreSnapshot(context: container.mainContext) == after)
    }

    @Test("moves an item to another list and restores it with one undo")
    func movesItemBetweenChecklists() throws {
        let container = try ModelContainerFactory.makeInMemory()
        let probe = SaveProbe(context: container.mainContext)
        let service = ChecklistMutationService(
            context: container.mainContext,
            saveOperation: { try probe.save() }
        )
        let sourceID = try service.createChecklist(named: "Inbox")
        let destinationID = try service.createChecklist(named: "Trip")
        try service.addItem(to: sourceID, title: "Passport")
        try service.addItem(to: destinationID, title: "Book hotel")
        let itemID = try #require(
            service.fetchChecklists().first(where: { $0.id == sourceID })?.items.first?.id
        )
        try service.toggleItem(id: itemID)
        let before = try ChecklistStoreSnapshot(context: container.mainContext)
        probe.resetCount()

        try service.moveItem(id: itemID, to: destinationID)

        #expect(probe.count == 1)
        let after = try ChecklistStoreSnapshot(context: container.mainContext)
        let destination = try #require(service.fetchChecklists().first(where: { $0.id == destinationID }))
        let moved = try #require(destination.items.first(where: { $0.id == itemID }))
        #expect(moved.title == "Passport")
        #expect(moved.isCompleted)
        #expect(destination.items.filter(\.isCompleted).last?.id == itemID)

        probe.resetCount()
        try service.undo()
        #expect(probe.count == 1)
        #expect(try ChecklistStoreSnapshot(context: container.mainContext) == before)

        probe.resetCount()
        try service.redo()
        #expect(probe.count == 1)
        #expect(try ChecklistStoreSnapshot(context: container.mainContext) == after)
    }

    @Test("duplicates a checklist with new identities and a collision-safe name")
    func duplicatesChecklist() throws {
        let container = try ModelContainerFactory.makeInMemory()
        let probe = SaveProbe(context: container.mainContext)
        let service = ChecklistMutationService(
            context: container.mainContext,
            saveOperation: { try probe.save() }
        )
        let sourceID = try service.createChecklist(named: "Packing")
        try service.addItem(to: sourceID, title: "Passport")
        let sourceItemID = try #require(service.fetchChecklists().first?.items.first?.id)
        try service.toggleItem(id: sourceItemID)
        _ = try service.createChecklist(named: "Packing Copy")
        probe.resetCount()

        let duplicateID = try service.duplicateChecklist(id: sourceID)

        #expect(probe.count == 1)
        let after = try ChecklistStoreSnapshot(context: container.mainContext)
        let duplicate = try #require(service.fetchChecklists().first(where: { $0.id == duplicateID }))
        #expect(duplicate.name == "Packing Copy 2")
        #expect(duplicate.items.map(\.title) == ["Passport"])
        #expect(duplicate.items.map(\.isCompleted) == [true])
        #expect(duplicate.items.first?.id != sourceItemID)

        probe.resetCount()
        try service.undo()
        #expect(probe.count == 1)
        #expect(try service.fetchChecklists().contains(where: { $0.id == duplicateID }) == false)

        probe.resetCount()
        try service.redo()
        #expect(probe.count == 1)
        #expect(try ChecklistStoreSnapshot(context: container.mainContext) == after)
    }

    @Test("item normalization does not reorder checklists")
    func itemMutationPreservesChecklistOrder() throws {
        let container = try ModelContainerFactory.makeInMemory()
        let service = ChecklistMutationService(context: container.mainContext)
        let firstID = try service.createChecklist(named: "First")
        let secondID = try service.createChecklist(named: "Second")
        try service.addItem(to: secondID, title: "Temporary")
        let itemID = try #require(
            service.fetchChecklists().first(where: { $0.id == secondID })?.items.first?.id
        )

        try service.deleteItem(id: itemID)

        #expect(try service.fetchChecklists().map(\.id) == [firstID, secondID])
    }

    @Test("a failed save rolls back and leaves no failed undo command")
    func failedSaveRollsBackAndCanRetry() throws {
        let container = try ModelContainerFactory.makeInMemory()
        let probe = SaveProbe(context: container.mainContext)
        let service = ChecklistMutationService(
            context: container.mainContext,
            saveOperation: { try probe.save() }
        )

        probe.shouldFail = true
        #expect(throws: ChecklistMutationError.self) {
            try service.createChecklist(named: "Retry me")
        }
        #expect(probe.count == 1)
        #expect(try service.fetchChecklists().isEmpty)
        #expect(!service.canUndo())

        probe.shouldFail = false
        probe.resetCount()
        let checklistID = try service.createChecklist(named: "Retry me")
        #expect(probe.count == 1)
        #expect(try service.fetchChecklists().map(\.id) == [checklistID])

        probe.shouldFail = true
        #expect(throws: ChecklistMutationError.self) {
            try service.addItem(to: checklistID, title: "Will retry")
        }
        #expect(try service.fetchChecklists().first?.items.isEmpty == true)

        // The only undoable command before the failed add is checklist
        // creation. Undoing here must remove the list rather than replaying a
        // phantom failed-add command.
        probe.shouldFail = false
        try service.undo()
        #expect(try service.fetchChecklists().isEmpty)
        probe.shouldFail = false
        probe.resetCount()
        try service.redo()
        #expect(probe.count == 1)

        probe.resetCount()
        try service.addItem(to: checklistID, title: "Will retry")
        #expect(probe.count == 1)
        #expect(try service.fetchChecklists().first?.items.map(\.title) == ["Will retry"])

        // A failed transaction must not enter history; the retry and its undo
        // therefore remain independent commands.
        try service.undo()
        #expect(try service.fetchChecklists().first?.items.isEmpty == true)
    }

    @Test("a failed undo remains available for a later retry")
    func failedUndoCanRetry() throws {
        let container = try ModelContainerFactory.makeInMemory()
        let probe = SaveProbe(context: container.mainContext)
        let service = ChecklistMutationService(
            context: container.mainContext,
            saveOperation: { try probe.save() }
        )

        let checklistID = try service.createChecklist(named: "Retry undo")
        #expect(try service.fetchChecklists().contains(where: { $0.id == checklistID }))

        probe.shouldFail = true
        #expect(throws: ChecklistMutationError.self) {
            try service.undo()
        }
        #expect(service.canUndo())
        #expect(!service.canRedo())
        #expect(try service.fetchChecklists().contains(where: { $0.id == checklistID }))

        probe.shouldFail = false
        probe.resetCount()
        try service.undo()
        #expect(probe.count == 1)
        #expect(try service.fetchChecklists().isEmpty)
        #expect(service.canRedo())
    }

    @Test("a failed redo remains available for a later retry")
    func failedRedoCanRetry() throws {
        let container = try ModelContainerFactory.makeInMemory()
        let probe = SaveProbe(context: container.mainContext)
        let service = ChecklistMutationService(
            context: container.mainContext,
            saveOperation: { try probe.save() }
        )

        let checklistID = try service.createChecklist(named: "Retry redo")
        try service.undo()
        #expect(try service.fetchChecklists().isEmpty)
        #expect(service.canRedo())
        #expect(!service.canUndo())

        probe.shouldFail = true
        #expect(throws: ChecklistMutationError.self) {
            try service.redo()
        }
        #expect(service.canRedo())
        #expect(!service.canUndo())
        #expect(try service.fetchChecklists().isEmpty)

        probe.shouldFail = false
        probe.resetCount()
        try service.redo()
        #expect(probe.count == 1)
        #expect(try service.fetchChecklists().contains(where: { $0.id == checklistID }))
        #expect(service.canUndo())
    }

    @Test("successful commands remain independently undoable")
    func commandsDoNotMergeIntoOneUndoStep() throws {
        let container = try ModelContainerFactory.makeInMemory()
        let service = ChecklistMutationService(context: container.mainContext)

        let checklistID = try service.createChecklist(named: "Independent commands")
        try service.addItem(to: checklistID, title: "One")

        try service.undo()
        #expect(try service.fetchChecklists().first?.items.isEmpty == true)
        #expect(service.canUndo())

        try service.undo()
        #expect(try service.fetchChecklists().isEmpty)
        #expect(!service.canUndo())
        #expect(service.canRedo())
    }

    @Test("a new successful command clears redo history")
    func newCommandClearsRedoHistory() throws {
        let container = try ModelContainerFactory.makeInMemory()
        let service = ChecklistMutationService(context: container.mainContext)
        let checklistID = try service.createChecklist(named: "Redo boundary")
        try service.addItem(to: checklistID, title: "First")

        try service.undo()
        #expect(service.canRedo())

        try service.addItem(to: checklistID, title: "Second")
        #expect(!service.canRedo())
        #expect(try service.fetchChecklists().first?.items.map(\.title) == ["Second"])
    }

    @Test("creates, mutates, and deletes checklist content")
    func mutatesChecklist() throws {
        let container = try ModelContainerFactory.makeInMemory()
        let service = ChecklistMutationService(context: container.mainContext)
        let checklistID = try service.createChecklist(named: "Work")

        try service.addItem(to: checklistID, title: "Ship report")
        try service.addItem(to: checklistID, title: "Call bank")
        try service.addItem(to: checklistID, title: "Book hotel")

        let checklist = try #require(service.fetchChecklists().first(where: { $0.id == checklistID }))
        #expect(checklist.items.count == 3)

        let itemID = try #require(checklist.items.first(where: { $0.title == "Ship report" })?.id)
        try service.toggleItem(id: itemID)
        #expect(checklist.items.first(where: { $0.id == itemID })?.isCompleted == true)

        let incompleteIDs = checklist.items
            .filter { !$0.isCompleted }
            .sorted(by: ChecklistOrderer.sortOrder)
            .map(\.id)
            .reversed()
        try service.reorderItems(in: checklistID, ids: Array(incompleteIDs))
        let reordered = try #require(service.fetchChecklists().first(where: { $0.id == checklistID }))
        #expect(reordered.items.filter { !$0.isCompleted }.map(\.title) == ["Book hotel", "Call bank"])
        #expect(reordered.items.filter(\.isCompleted).map(\.title) == ["Ship report"])

        try service.clearCompleted(in: checklistID)
        let afterClear = try #require(service.fetchChecklists().first(where: { $0.id == checklistID }))
        #expect(afterClear.items.count == 2)

        let secondChecklistID = try service.createChecklist(named: "Personal")
        try service.deleteChecklist(id: checklistID)
        let remaining = try service.fetchChecklists()
        #expect(remaining.map(\.id) == [secondChecklistID])
    }

    @Test("does not allow deleting the last checklist")
    func protectsLastChecklist() throws {
        let container = try ModelContainerFactory.makeInMemory()
        let service = ChecklistMutationService(context: container.mainContext)
        let checklistID = try service.createChecklist(named: "Only list")

        #expect(throws: ChecklistMutationError.self) {
            try service.deleteChecklist(id: checklistID)
        }
    }

    @Test("renames checklists and edits item titles")
    func renamesAndEditsItems() throws {
        let container = try ModelContainerFactory.makeInMemory()
        let service = ChecklistMutationService(context: container.mainContext)
        let workID = try service.createChecklist(named: "Work")
        _ = try service.createChecklist(named: "Personal")

        try service.renameChecklist(id: workID, to: "  Projects  ")
        let renamed = try #require(service.fetchChecklists().first(where: { $0.id == workID }))
        #expect(renamed.name == "Projects")

        try service.addItem(to: workID, title: "Draft report")
        let itemID = try #require(renamed.items.first?.id)
        try service.updateItem(id: itemID, title: "  Send report  ")
        #expect(renamed.items.first?.title == "Send report")

        #expect(throws: ChecklistInputError.self) {
            try service.renameChecklist(id: workID, to: "personal")
        }
    }

    @Test("rejects a blank item edit without changing the durable title")
    func rejectsBlankItemEdit() throws {
        let container = try ModelContainerFactory.makeInMemory()
        let service = ChecklistMutationService(context: container.mainContext)
        let checklistID = try service.createChecklist(named: "Work")
        try service.addItem(to: checklistID, title: "Keep this title")
        let item = try #require(service.fetchChecklists().first?.items.first)
        let originalUpdatedAt = item.updatedAt

        #expect(throws: ChecklistInputError.self) {
            try service.updateItem(id: item.id, title: " \n ")
        }

        let unchanged = try #require(service.fetchChecklists().first?.items.first)
        #expect(unchanged.title == "Keep this title")
        #expect(unchanged.updatedAt == originalUpdatedAt)
    }

    @Test("updates timestamps while preserving item order on completion changes")
    func updatesTimestampsWithoutChangingOrder() throws {
        let container = try ModelContainerFactory.makeInMemory()
        let service = ChecklistMutationService(context: container.mainContext)
        let checklistID = try service.createChecklist(named: "Work")
        try service.addItem(to: checklistID, title: "One")
        try service.addItem(to: checklistID, title: "Two")

        let before = try #require(service.fetchChecklists().first)
        let item = try #require(before.items.first(where: { $0.title == "One" }))
        let beforeListUpdatedAt = before.updatedAt
        let beforeItemUpdatedAt = item.updatedAt
        let beforeSortOrder = item.sortOrder

        try service.toggleItem(id: item.id)

        let after = try #require(service.fetchChecklists().first)
        let updatedItem = try #require(after.items.first(where: { $0.id == item.id }))
        #expect(after.updatedAt >= beforeListUpdatedAt)
        #expect(updatedItem.updatedAt >= beforeItemUpdatedAt)
        #expect(updatedItem.sortOrder == beforeSortOrder)
    }

    @Test("touches timestamps for list and item mutations")
    func updatesTimestampsForMutations() throws {
        let container = try ModelContainerFactory.makeInMemory()
        let service = ChecklistMutationService(context: container.mainContext)
        let firstID = try service.createChecklist(named: "First")
        let first = try #require(service.fetchChecklists().first)
        let firstCreatedAt = first.createdAt
        let firstUpdatedAt = first.updatedAt

        try service.renameChecklist(id: firstID, to: "Renamed")
        let afterRename = try #require(service.fetchChecklists().first)
        #expect(afterRename.createdAt == firstCreatedAt)
        #expect(afterRename.updatedAt >= firstUpdatedAt)

        let secondID = try service.createChecklist(named: "Second")
        let beforeListReorderUpdatedAt = try #require(
            service.fetchChecklists().first(where: { $0.id == firstID })?.updatedAt
        )
        try service.reorderChecklists(ids: [secondID, firstID])
        let afterListReorder = try #require(service.fetchChecklists().first(where: { $0.id == firstID }))
        #expect(afterListReorder.updatedAt >= beforeListReorderUpdatedAt)

        let beforeAdd = afterListReorder.updatedAt
        try service.addItem(to: firstID, title: "Item")
        let afterAdd = try #require(service.fetchChecklists().first(where: { $0.id == firstID }))
        let item = try #require(afterAdd.items.first)
        #expect(item.createdAt <= item.updatedAt)
        #expect(afterAdd.updatedAt >= beforeAdd)

        let beforeEdit = item.updatedAt
        try service.updateItem(id: item.id, title: "Edited")
        let edited = try #require(service.fetchChecklists().first(where: { $0.id == firstID })?.items.first)
        #expect(edited.updatedAt >= beforeEdit)

        let beforeToggle = edited.updatedAt
        try service.toggleItem(id: edited.id)
        let toggled = try #require(service.fetchChecklists().first(where: { $0.id == firstID })?.items.first)
        #expect(toggled.updatedAt >= beforeToggle)

        let beforeItemReorderUpdatedAt = try #require(
            service.fetchChecklists().first(where: { $0.id == firstID })?.updatedAt
        )
        try service.reorderItems(in: firstID, ids: [toggled.id])
        let afterItemReorder = try #require(service.fetchChecklists().first(where: { $0.id == firstID }))
        #expect(afterItemReorder.updatedAt >= beforeItemReorderUpdatedAt)

        let beforeClear = afterItemReorder.updatedAt
        try service.clearCompleted(in: firstID)
        let afterClear = try #require(service.fetchChecklists().first(where: { $0.id == firstID }))
        #expect(afterClear.updatedAt >= beforeClear)
    }

    @Test("deletes an item without deleting its checklist")
    func deletesItem() throws {
        let container = try ModelContainerFactory.makeInMemory()
        let service = ChecklistMutationService(context: container.mainContext)
        let checklistID = try service.createChecklist(named: "Work")
        try service.addItem(to: checklistID, title: "Temporary")
        let checklist = try #require(service.fetchChecklists().first)
        let itemID = try #require(checklist.items.first?.id)

        try service.deleteItem(id: itemID)

        let remaining = try #require(service.fetchChecklists().first)
        #expect(remaining.id == checklistID)
        #expect(remaining.items.isEmpty)
    }

    @Test("normalizes remaining item order after deletion")
    func normalizesOrderAfterItemDeletion() throws {
        let container = try ModelContainerFactory.makeInMemory()
        let service = ChecklistMutationService(context: container.mainContext)
        let checklistID = try service.createChecklist(named: "Work")
        try service.addItem(to: checklistID, title: "One")
        try service.addItem(to: checklistID, title: "Two")
        try service.addItem(to: checklistID, title: "Three")
        let items = try #require(service.fetchChecklists().first?.items.sorted(by: ChecklistOrderer.itemSort))

        try service.deleteItem(id: items[1].id)

        let remaining = try #require(service.fetchChecklists().first?.items.sorted(by: ChecklistOrderer.itemSort))
        #expect(remaining.map(\.title) == ["One", "Three"])
        #expect(remaining.map(\.sortOrder) == [0, 1])
    }

    @Test("normalizes remaining order after clearing completed items")
    func normalizesOrderAfterClearCompleted() throws {
        let container = try ModelContainerFactory.makeInMemory()
        let service = ChecklistMutationService(context: container.mainContext)
        let checklistID = try service.createChecklist(named: "Work")
        try service.addItem(to: checklistID, title: "Keep")
        try service.addItem(to: checklistID, title: "Remove")
        let removeID = try #require(service.fetchChecklists().first?.items.first(where: { $0.title == "Remove" })?.id)
        try service.toggleItem(id: removeID)

        try service.clearCompleted(in: checklistID)

        let remaining = try #require(service.fetchChecklists().first?.items.first)
        #expect(remaining.title == "Keep")
        #expect(remaining.sortOrder == 0)
    }

    @Test("reorders checklists by the requested IDs")
    func reordersChecklists() throws {
        let container = try ModelContainerFactory.makeInMemory()
        let service = ChecklistMutationService(context: container.mainContext)
        let firstID = try service.createChecklist(named: "First")
        let secondID = try service.createChecklist(named: "Second")
        let thirdID = try service.createChecklist(named: "Third")

        try service.reorderChecklists(ids: [thirdID, firstID, secondID])

        #expect(try service.fetchChecklists().map(\.id) == [thirdID, firstID, secondID])
    }

    @Test("appends a new checklist after the highest persisted order")
    func createsChecklistAfterHighestOrder() throws {
        let container = try ModelContainerFactory.makeInMemory()
        let context = container.mainContext
        let first = Checklist(name: "First", sortOrder: 10)
        let second = Checklist(name: "Second", sortOrder: 20)
        context.insert(first)
        context.insert(second)
        try context.save()

        let service = ChecklistMutationService(context: context)
        let createdID = try service.createChecklist(named: "Third")
        let created = try #require(service.fetchChecklists().first(where: { $0.id == createdID }))

        #expect(created.sortOrder == 21)
        #expect(try service.fetchChecklists().map(\.name) == ["First", "Second", "Third"])
    }

    @Test("marks every completed item incomplete")
    func marksAllItemsIncomplete() throws {
        let container = try ModelContainerFactory.makeInMemory()
        let service = ChecklistMutationService(context: container.mainContext)
        let checklistID = try service.createChecklist(named: "Work")
        try service.addItem(to: checklistID, title: "One")
        try service.addItem(to: checklistID, title: "Two")
        let checklist = try #require(service.fetchChecklists().first)
        let firstID = try #require(checklist.items.first?.id)
        try service.toggleItem(id: firstID)

        try service.markAllIncomplete(in: checklistID)

        #expect(checklist.items.allSatisfy { !$0.isCompleted })
    }

    @Test("rejects an item reorder with missing or mixed-completion IDs")
    func rejectsInvalidItemReorder() throws {
        let container = try ModelContainerFactory.makeInMemory()
        let service = ChecklistMutationService(context: container.mainContext)
        let checklistID = try service.createChecklist(named: "Work")
        try service.addItem(to: checklistID, title: "One")
        try service.addItem(to: checklistID, title: "Two")
        let checklist = try #require(service.fetchChecklists().first)
        let ids = checklist.items.sorted(by: ChecklistOrderer.itemSort).map(\.id)

        #expect(throws: ChecklistMutationError.self) {
            try service.reorderItems(in: checklistID, ids: [ids[0], ids[0]])
        }

        try service.toggleItem(id: ids[0])
        #expect(throws: ChecklistMutationError.self) {
            try service.reorderItems(in: checklistID, ids: ids)
        }
    }

    @Test("reorders completed items without moving incomplete items")
    func reordersCompletedGroup() throws {
        let container = try ModelContainerFactory.makeInMemory()
        let service = ChecklistMutationService(context: container.mainContext)
        let checklistID = try service.createChecklist(named: "Work")
        for title in ["Todo one", "Todo two", "Done one", "Done two"] {
            try service.addItem(to: checklistID, title: title)
        }
        let items = try #require(service.fetchChecklists().first?.items)
        for title in ["Done one", "Done two"] {
            let id = try #require(items.first(where: { $0.title == title })?.id)
            try service.toggleItem(id: id)
        }
        let completedIDs = try #require(service.fetchChecklists().first?.items
            .filter(\.isCompleted)
            .sorted(by: ChecklistOrderer.itemSort)
            .map(\.id))

        try service.reorderItems(in: checklistID, ids: Array(completedIDs.reversed()))

        let reordered = try #require(service.fetchChecklists().first)
        #expect(reordered.items.filter { !$0.isCompleted }.map(\.title) == ["Todo one", "Todo two"])
        #expect(reordered.items.filter(\.isCompleted).map(\.title) == ["Done two", "Done one"])
    }

    @Test("deleting a checklist cascades to its items")
    func deletesChecklistAndItems() throws {
        let container = try ModelContainerFactory.makeInMemory()
        let service = ChecklistMutationService(context: container.mainContext)
        let firstID = try service.createChecklist(named: "First")
        _ = try service.createChecklist(named: "Second")
        try service.addItem(to: firstID, title: "Remove with list")

        try service.deleteChecklist(id: firstID)

        let items = try container.mainContext.fetch(FetchDescriptor<ChecklistItem>())
        #expect(items.isEmpty)
    }

    @Test("undoes and redoes the most recent saved mutation")
    func undoesAndRedoesMutation() throws {
        let container = try ModelContainerFactory.makeInMemory()
        let service = ChecklistMutationService(context: container.mainContext)
        let checklistID = try service.createChecklist(named: "Work")
        try service.addItem(to: checklistID, title: "Undo me")
        #expect(service.canUndo())

        try service.undo()
        let afterUndo = try #require(service.fetchChecklists().first)
        #expect(afterUndo.items.isEmpty)
        #expect(service.canRedo())

        try service.redo()
        let afterRedo = try #require(service.fetchChecklists().first)
        #expect(afterRedo.items.map(\.title) == ["Undo me"])
    }

    @Test("undo and redo restore exact item command snapshots")
    func undoRedoItemCommands() throws {
        let container = try ModelContainerFactory.makeInMemory()
        let service = ChecklistMutationService(context: container.mainContext)
        let checklistID = try service.createChecklist(named: "Work")
        try service.addItem(to: checklistID, title: "First")
        try service.addItem(to: checklistID, title: "Second")

        let firstID = try #require(service.fetchChecklists().first?.items.first(where: { $0.title == "First" })?.id)
        let beforeEdit = try ChecklistStoreSnapshot(context: container.mainContext)
        try service.updateItem(id: firstID, title: "Renamed")
        let afterEdit = try ChecklistStoreSnapshot(context: container.mainContext)
        try assertUndoRedo(service, context: container.mainContext, before: beforeEdit, after: afterEdit)

        let beforeToggle = try ChecklistStoreSnapshot(context: container.mainContext)
        try service.toggleItem(id: firstID)
        let afterToggle = try ChecklistStoreSnapshot(context: container.mainContext)
        try assertUndoRedo(service, context: container.mainContext, before: beforeToggle, after: afterToggle)

        let incompleteIDs = try #require(service.fetchChecklists().first?.items
            .filter { !$0.isCompleted }
            .sorted(by: ChecklistOrderer.itemSort)
            .map(\.id))
        let beforeReorder = try ChecklistStoreSnapshot(context: container.mainContext)
        try service.reorderItems(in: checklistID, ids: Array(incompleteIDs.reversed()))
        let afterReorder = try ChecklistStoreSnapshot(context: container.mainContext)
        try assertUndoRedo(service, context: container.mainContext, before: beforeReorder, after: afterReorder)

        let completedID = try #require(service.fetchChecklists().first?.items.first?.id)
        if let item = try service.fetchChecklists().first?.items.first,
           !item.isCompleted {
            try service.toggleItem(id: completedID)
        }
        let beforeClear = try ChecklistStoreSnapshot(context: container.mainContext)
        try service.clearCompleted(in: checklistID)
        let afterClear = try ChecklistStoreSnapshot(context: container.mainContext)
        try assertUndoRedo(service, context: container.mainContext, before: beforeClear, after: afterClear)
    }

    @Test("undo and redo restore exact list commands")
    func undoRedoListCommands() throws {
        let container = try ModelContainerFactory.makeInMemory()
        let service = ChecklistMutationService(context: container.mainContext)
        let beforeCreate = try ChecklistStoreSnapshot(context: container.mainContext)
        let createdID = try service.createChecklist(named: "Created")
        let afterCreate = try ChecklistStoreSnapshot(context: container.mainContext)
        try assertUndoRedo(service, context: container.mainContext, before: beforeCreate, after: afterCreate)

        // Continue with two durable lists so the delete-last-list guard does
        // not interfere with the delete undo command below. The created list
        // remains part of the store and must be included in every reorder.
        let firstID = try service.createChecklist(named: "First")
        let secondID = try service.createChecklist(named: "Second")

        let beforeRename = try ChecklistStoreSnapshot(context: container.mainContext)
        try service.renameChecklist(id: secondID, to: "Renamed")
        let afterRename = try ChecklistStoreSnapshot(context: container.mainContext)
        try assertUndoRedo(service, context: container.mainContext, before: beforeRename, after: afterRename)

        let beforeReorder = try ChecklistStoreSnapshot(context: container.mainContext)
        try service.reorderChecklists(ids: [secondID, firstID, createdID])
        let afterReorder = try ChecklistStoreSnapshot(context: container.mainContext)
        try assertUndoRedo(service, context: container.mainContext, before: beforeReorder, after: afterReorder)

        let beforeDelete = try ChecklistStoreSnapshot(context: container.mainContext)
        try service.deleteChecklist(id: firstID)
        let afterDelete = try ChecklistStoreSnapshot(context: container.mainContext)
        try assertUndoRedo(service, context: container.mainContext, before: beforeDelete, after: afterDelete)

        #expect(try service.fetchChecklists().contains(where: { $0.id == createdID }))
    }

    @Test("undo and redo restore exact item deletion")
    func undoRedoItemDeletion() throws {
        let container = try ModelContainerFactory.makeInMemory()
        let service = ChecklistMutationService(context: container.mainContext)
        let checklistID = try service.createChecklist(named: "Work")
        try service.addItem(to: checklistID, title: "Delete me")
        let itemID = try #require(service.fetchChecklists().first?.items.first?.id)

        let before = try ChecklistStoreSnapshot(context: container.mainContext)
        try service.deleteItem(id: itemID)
        let after = try ChecklistStoreSnapshot(context: container.mainContext)
        try assertUndoRedo(service, context: container.mainContext, before: before, after: after)
    }

    @Test("mark all incomplete is one undoable bulk command")
    func undoRedoMarkAllIncomplete() throws {
        let container = try ModelContainerFactory.makeInMemory()
        let service = ChecklistMutationService(context: container.mainContext)
        let checklistID = try service.createChecklist(named: "Work")
        try service.addItem(to: checklistID, title: "One")
        try service.addItem(to: checklistID, title: "Two")
        let itemIDs = try #require(service.fetchChecklists().first?.items.map(\.id))
        try service.toggleItem(id: itemIDs[0])
        try service.toggleItem(id: itemIDs[1])

        let before = try ChecklistStoreSnapshot(context: container.mainContext)
        try service.markAllIncomplete(in: checklistID)
        let after = try ChecklistStoreSnapshot(context: container.mainContext)
        #expect(after.lists.first?.items.allSatisfy { !$0.isCompleted } == true)

        try assertUndoRedo(service, context: container.mainContext, before: before, after: after)
    }

    private func assertUndoRedo(
        _ service: ChecklistMutationService,
        context: ModelContext,
        before: ChecklistStoreSnapshot,
        after: ChecklistStoreSnapshot
    ) throws {
        try service.undo()
        #expect(try ChecklistStoreSnapshot(context: context) == before)
        try service.redo()
        #expect(try ChecklistStoreSnapshot(context: context) == after)
    }

    @Test("reopens a persistent store and retains checklist content")
    func recreatesPersistentStore() throws {
        let schema = Schema(versionedSchema: ChecklistSchemaV1.self)
        let storeDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SimplisticChecklistTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(
            at: storeDirectory,
            withIntermediateDirectories: true
        )
        let storeURL = storeDirectory.appendingPathComponent("Store.sqlite")
        let configuration = ModelConfiguration(
            "PersistenceTest",
            schema: schema,
            url: storeURL,
            allowsSave: true,
            cloudKitDatabase: .none
        )
        defer { try? FileManager.default.removeItem(at: storeDirectory) }

        do {
            let firstContainer = try ModelContainer(
                for: schema,
                migrationPlan: ChecklistSchemaMigrationPlan.self,
                configurations: [configuration]
            )
            let firstService = ChecklistMutationService(context: firstContainer.mainContext)
            let checklistID = try firstService.createChecklist(named: "Persisted")
            try firstService.addItem(to: checklistID, title: "First persisted item")
            try firstService.addItem(to: checklistID, title: "Second persisted item")
            let items = try #require(firstService.fetchChecklists().first?.items)
            try firstService.reorderItems(
                in: checklistID,
                ids: [items[1].id, items[0].id]
            )
            let otherID = try firstService.createChecklist(named: "Other")
            try firstService.reorderChecklists(ids: [otherID, checklistID])
        }

        do {
            let secondContainer = try ModelContainer(
                for: schema,
                migrationPlan: ChecklistSchemaMigrationPlan.self,
                configurations: [configuration]
            )
            let secondService = ChecklistMutationService(context: secondContainer.mainContext)
            let reopened = try #require(
                secondService.fetchChecklists().first(where: { $0.name == "Persisted" })
            )

            #expect(reopened.name == "Persisted")
            #expect(reopened.items.map(\.title) == ["Second persisted item", "First persisted item"])
            #expect(try secondService.fetchChecklists().map(\.name) == ["Other", "Persisted"])
        }
    }
}

@MainActor
private final class SaveProbe {
    let context: ModelContext
    var count = 0
    var shouldFail = false

    init(context: ModelContext) {
        self.context = context
    }

    func save() throws {
        count += 1
        if shouldFail {
            throw ProbeSaveError()
        }
        try context.save()
    }

    func resetCount() {
        count = 0
    }
}

private struct ProbeSaveError: Error {}
