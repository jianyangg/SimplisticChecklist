import Foundation
import Testing
@testable import SimplisticChecklist

@Suite("Checklist quality-of-life helpers")
struct ChecklistQualityOfLifeTests {
    @Test("bulk entry trims lines and ignores empty lines")
    func parsesBulkEntry() throws {
        let text = "  Passport  \n\nBook hotel\n   \nCall bank  "

        #expect(try ChecklistBulkItemParser.titles(from: text) == [
            "Passport",
            "Book hotel",
            "Call bank"
        ])
    }

    @Test("bulk entry rejects empty input and an over-limit line")
    func validatesBulkEntry() {
        #expect(throws: ChecklistInputError.self) {
            try ChecklistBulkItemParser.titles(from: " \n\n ")
        }
        #expect(throws: ChecklistInputError.self) {
            try ChecklistBulkItemParser.titles(
                from: String(repeating: "I", count: ChecklistInputValidator.maximumItemTitleLength + 1)
            )
        }
    }

    @Test("plain-text sharing preserves grouping and user text")
    func exportsPlainText() {
        let checklist = Checklist(name: "Trip", items: [
            ChecklistItem(title: "Passport", sortOrder: 0),
            ChecklistItem(title: "Book hotel", isCompleted: true, sortOrder: 1)
        ])

        #expect(ChecklistTextExporter.text(for: checklist) == """
        Trip

        [ ] Passport
        [x] Book hotel
        """)
    }

    @Test("completed visibility is remembered independently per checklist")
    func remembersCompletedVisibility() throws {
        let suiteName = "SimplisticChecklistTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let preferences = ChecklistDisplayPreferences(defaults: defaults)
        let firstID = UUID()
        let secondID = UUID()

        #expect(preferences.showsCompleted(for: firstID))
        preferences.setShowsCompleted(false, for: firstID)

        #expect(!preferences.showsCompleted(for: firstID))
        #expect(preferences.showsCompleted(for: secondID))
    }

    @Test("duplicate names remain within the list-name limit")
    func boundsDuplicateNames() {
        let source = String(repeating: "L", count: ChecklistInputValidator.maximumListNameLength)
        let first = ChecklistDuplicateNameGenerator.name(for: source, existingNames: [source])
        let second = ChecklistDuplicateNameGenerator.name(
            for: source,
            existingNames: [source, first]
        )

        #expect(first.count <= ChecklistInputValidator.maximumListNameLength)
        #expect(second.count <= ChecklistInputValidator.maximumListNameLength)
        #expect(first.hasSuffix(" Copy"))
        #expect(second.hasSuffix(" Copy 2"))
    }
}
