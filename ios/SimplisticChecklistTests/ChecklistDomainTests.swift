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
}
