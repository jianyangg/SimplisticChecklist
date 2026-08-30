import Foundation
import SwiftData
import Testing
@testable import SimplisticChecklist

@MainActor
@Suite("Checklist persistence mutations")
struct ChecklistMutationServiceTests {
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

    @Test("reopens a persistent store and retains checklist content")
    func recreatesPersistentStore() throws {
        let schema = Schema(versionedSchema: ChecklistSchemaV1.self)
        let storeURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("SimplisticChecklistTests-\(UUID().uuidString).store")
        let configuration = ModelConfiguration(
            "PersistenceTest",
            schema: schema,
            url: storeURL,
            allowsSave: true,
            cloudKitDatabase: .none
        )
        defer { try? FileManager.default.removeItem(at: storeURL) }

        let firstContainer = try ModelContainer(
            for: schema,
            migrationPlan: ChecklistSchemaMigrationPlan.self,
            configurations: [configuration]
        )
        let firstService = ChecklistMutationService(context: firstContainer.mainContext)
        let checklistID = try firstService.createChecklist(named: "Persisted")
        try firstService.addItem(to: checklistID, title: "Survives relaunch")

        let secondContainer = try ModelContainer(
            for: schema,
            migrationPlan: ChecklistSchemaMigrationPlan.self,
            configurations: [configuration]
        )
        let secondService = ChecklistMutationService(context: secondContainer.mainContext)
        let reopened = try #require(secondService.fetchChecklists().first)

        #expect(reopened.name == "Persisted")
        #expect(reopened.items.map(\.title) == ["Survives relaunch"])
    }
}
