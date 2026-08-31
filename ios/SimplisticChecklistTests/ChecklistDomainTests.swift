import Foundation
import Testing
@testable import SimplisticChecklist

@Suite("Checklist input and ordering")
struct ChecklistDomainTests {
    @Test("normalizes valid names and item titles")
    func normalizesInput() throws {
        #expect(try ChecklistInputValidator.listName("  Work  ") == "Work")
        #expect(try ChecklistInputValidator.itemTitle("\nBuy milk  ") == "Buy milk")
    }

    @Test("rejects empty and duplicate names")
    func rejectsInvalidNames() {
        #expect(throws: ChecklistInputError.self) {
            try ChecklistInputValidator.listName(" \n")
        }
        #expect(throws: ChecklistInputError.self) {
            try ChecklistInputValidator.listName("work", existingNames: ["Work"])
        }
    }

    @Test("accepts the documented input limits and rejects one character over")
    func enforcesInputBoundaries() throws {
        let validListName = String(repeating: "L", count: ChecklistInputValidator.maximumListNameLength)
        let longListName = validListName + "L"
        let validItemTitle = String(repeating: "I", count: ChecklistInputValidator.maximumItemTitleLength)
        let longItemTitle = validItemTitle + "I"

        #expect(try ChecklistInputValidator.listName(validListName) == validListName)
        #expect(throws: ChecklistInputError.self) {
            try ChecklistInputValidator.listName(longListName)
        }
        #expect(try ChecklistInputValidator.itemTitle(validItemTitle) == validItemTitle)
        #expect(throws: ChecklistInputError.self) {
            try ChecklistInputValidator.itemTitle(longItemTitle)
        }
    }

    @Test("sorts incomplete items before completed items while preserving order")
    func sortsItems() {
        let first = ChecklistItem(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001") ?? UUID(),
            title: "First",
            sortOrder: 0
        )
        let done = ChecklistItem(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000002") ?? UUID(),
            title: "Done",
            isCompleted: true,
            sortOrder: 0
        )
        let second = ChecklistItem(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000003") ?? UUID(),
            title: "Second",
            sortOrder: 1
        )

        let result = [done, second, first].sorted(by: ChecklistOrderer.itemSort)
        #expect(result.map(\.title) == ["First", "Second", "Done"])
    }

    @Test("reorder IDs reject missing or duplicate members")
    func validatesReorderIDs() {
        let first = ChecklistItem(title: "First")
        let second = ChecklistItem(title: "Second")
        let group = [first, second]

        #expect(ChecklistOrderer.normalizedIDs([second.id, first.id], from: group) == [second.id, first.id])
        #expect(ChecklistOrderer.normalizedIDs([first.id, first.id], from: group) == [first.id])
    }

    @Test("uses UUID as the final deterministic tie breaker")
    func sortsEqualOrdersDeterministically() {
        let olderID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let newerID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
        let timestamp = Date(timeIntervalSinceReferenceDate: 100)
        let first = ChecklistItem(
            id: newerID,
            title: "Second",
            sortOrder: 0,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        let second = ChecklistItem(
            id: olderID,
            title: "First",
            sortOrder: 0,
            createdAt: timestamp,
            updatedAt: timestamp
        )

        #expect([first, second].sorted(by: ChecklistOrderer.itemSort).map(\.id) == [olderID, newerID])
    }

    @Test("normalizes gaps and duplicate order values")
    func normalizesOrderValues() {
        let timestamp = Date(timeIntervalSinceReferenceDate: 100)
        let checklist = Checklist(
            name: "Work",
            sortOrder: 8,
            createdAt: timestamp,
            updatedAt: timestamp,
            items: [
                ChecklistItem(
                    id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
                    title: "Done",
                    isCompleted: true,
                    sortOrder: 20,
                    createdAt: timestamp,
                    updatedAt: timestamp
                ),
                ChecklistItem(
                    id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
                    title: "Todo",
                    sortOrder: 20,
                    createdAt: timestamp,
                    updatedAt: timestamp
                )
            ]
        )

        ChecklistOrderer.normalize([checklist])

        #expect(checklist.sortOrder == 0)
        #expect(checklist.items.sorted(by: ChecklistOrderer.itemSort).map(\.title) == ["Todo", "Done"])
        #expect(checklist.items.map(\.sortOrder).sorted() == [0, 1])
    }
}
