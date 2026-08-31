import Foundation
import Testing
@testable import SimplisticChecklist

@Suite("Checklist selection")
struct ChecklistSelectionResolverTests {
    @Test("keeps a valid selection")
    func keepsValidSelection() {
        let first = Checklist(name: "First", sortOrder: 0)
        let second = Checklist(name: "Second", sortOrder: 1)

        #expect(ChecklistSelectionResolver.resolve(preferred: second.id, in: [first, second]) == second.id)
    }

    @Test("falls back after the selected checklist is deleted")
    func fallsBackAfterDeletion() {
        let first = Checklist(name: "First", sortOrder: 0)
        let second = Checklist(name: "Second", sortOrder: 1)

        #expect(ChecklistSelectionResolver.resolve(preferred: second.id, in: [first]) == first.id)
        #expect(ChecklistSelectionResolver.resolve(preferred: UUID(), in: []) == nil)
    }
}
