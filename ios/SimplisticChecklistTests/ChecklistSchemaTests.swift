import Foundation
import SwiftData
import Testing
@testable import SimplisticChecklist

@MainActor
@Suite("SwiftData schema")
struct ChecklistSchemaTests {
    @Test("creates the versioned schema and persists its relationships")
    func createsSchema() throws {
        let container = try ModelContainerFactory.makeInMemory()
        let context = container.mainContext
        let checklist = Checklist(name: "Schema")
        let item = ChecklistItem(title: "Persisted")
        context.insert(checklist)
        context.insert(item)
        checklist.items.append(item)
        try context.save()

        let fetchedList = try #require(context.fetch(FetchDescriptor<Checklist>()).first)
        #expect(fetchedList.items.map(\.title) == ["Persisted"])
        #expect(ChecklistSchemaV1.models.count == 3)
    }

    @Test("new checklist and item models receive distinct stable UUIDs")
    func generatedUUIDsAreDistinct() {
        let firstChecklist = Checklist(name: "First")
        let secondChecklist = Checklist(name: "Second")
        let firstItem = ChecklistItem(title: "First")
        let secondItem = ChecklistItem(title: "Second")

        #expect(firstChecklist.id != secondChecklist.id)
        #expect(firstItem.id != secondItem.id)
        #expect(firstChecklist.id != firstItem.id)
    }
}
