import Foundation
import SwiftData
import Testing
@testable import SimplisticChecklist

@MainActor
@Suite("Legacy migration")
struct LegacyChecklistMigratorTests {
    @Test("imports legacy data once and preserves the previous selection")
    func importsOnce() throws {
        let suiteName = "SimplisticChecklistTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        defaults.set(["Work", "Errands"], forKey: LegacyPreferenceKeys.masterChecklistKey)
        defaults.set(["Ship report", "Call bank"], forKey: LegacyPreferenceKeys.itemKey(for: "Work"))
        defaults.set(["false", "true"], forKey: LegacyPreferenceKeys.completionKey(for: "Work"))
        defaults.set(["Buy milk"], forKey: LegacyPreferenceKeys.itemKey(for: "Errands"))
        defaults.set(["false"], forKey: LegacyPreferenceKeys.completionKey(for: "Errands"))
        defaults.set("Errands", forKey: LegacyPreferenceKeys.lastLoadedListKey)

        let container = try ModelContainerFactory.makeInMemory()
        let context = container.mainContext
        let migrator = LegacyChecklistMigrator(context: context, defaults: defaults)

        let firstResult = try migrator.migrateIfNeeded()
        #expect(firstResult.imported)

        let importedLists = try context.fetch(FetchDescriptor<Checklist>())
            .sorted(by: ChecklistOrderer.checklistSort)
        #expect(importedLists.map(\.name) == ["Work", "Errands"])
        #expect(importedLists[0].items.count == 2)
        #expect(importedLists[0].items.map(\.isCompleted) == [false, true])
        #expect(firstResult.selectedChecklistID == importedLists[1].id)
        #expect(defaults.bool(forKey: LegacyPreferenceKeys.nativeMigrationCompleted))
        #expect(defaults.object(forKey: LegacyPreferenceKeys.masterChecklistKey) != nil)
        #expect(try context.fetch(FetchDescriptor<ChecklistMigrationReceipt>()).count == 1)

        let secondResult = try migrator.migrateIfNeeded()
        #expect(!secondResult.imported)
        #expect(secondResult.selectedChecklistID == firstResult.selectedChecklistID)
        #expect(try context.fetch(FetchDescriptor<Checklist>()).count == 2)
    }

    @Test("preserves case-colliding and whitespace-only legacy list names")
    func preservesLegacyNameCollisions() throws {
        let suiteName = "SimplisticChecklistTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        defaults.set(["Work", "work", "   "], forKey: LegacyPreferenceKeys.masterChecklistKey)
        defaults.set(["First"], forKey: LegacyPreferenceKeys.itemKey(for: "Work"))
        defaults.set(["Second"], forKey: LegacyPreferenceKeys.itemKey(for: "work"))
        defaults.set(["Recovered"], forKey: LegacyPreferenceKeys.itemKey(for: "   "))
        defaults.set("work", forKey: LegacyPreferenceKeys.lastLoadedListKey)

        let container = try ModelContainerFactory.makeInMemory()
        let context = container.mainContext
        let result = try LegacyChecklistMigrator(context: context, defaults: defaults).migrateIfNeeded()
        let lists = try context.fetch(FetchDescriptor<Checklist>()).sorted(by: ChecklistOrderer.checklistSort)

        #expect(lists.map(\.name) == ["Work", "work 2", "Untitled List"])
        #expect(lists.map { $0.items.map(\.title) } == [["First"], ["Second"], ["Recovered"]])
        #expect(result.selectedChecklistID == lists[1].id)
        #expect(result.diagnostics.usedFallbackNames == 1)
    }

    @Test("does not let a UserDefaults marker suppress recovery after store loss")
    func markerAloneDoesNotSuppressRecovery() throws {
        let suiteName = "SimplisticChecklistTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        defaults.set(true, forKey: LegacyPreferenceKeys.nativeMigrationCompleted)
        defaults.set(["Work"], forKey: LegacyPreferenceKeys.masterChecklistKey)
        defaults.set(["Ship report"], forKey: LegacyPreferenceKeys.itemKey(for: "Work"))
        defaults.set(["false"], forKey: LegacyPreferenceKeys.completionKey(for: "Work"))

        let container = try ModelContainerFactory.makeInMemory()
        let context = container.mainContext
        let result = try LegacyChecklistMigrator(context: context, defaults: defaults).migrateIfNeeded()
        let lists = try context.fetch(FetchDescriptor<Checklist>()).sorted(by: ChecklistOrderer.checklistSort)

        #expect(result.imported)
        #expect(lists.map(\.name) == ["Work"])
        #expect(lists.first?.items.map(\.title) == ["Ship report"])
    }

    @Test("keeps recovered tutorial edits separate from a user Checklist")
    func keepsRecoveredTutorialSeparate() throws {
        let suiteName = "SimplisticChecklistTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let tutorialItem = try #require(LegacyChecklistParser.tutorialItemTitles.first)

        defaults.set(["Checklist"], forKey: LegacyPreferenceKeys.masterChecklistKey)
        defaults.set(["User list task"], forKey: LegacyPreferenceKeys.itemKey(for: "Checklist"))
        defaults.set(["false"], forKey: LegacyPreferenceKeys.completionKey(for: "Checklist"))
        defaults.set([tutorialItem, "Tutorial custom task"], forKey: LegacyPreferenceKeys.tutorialChecklistKey)
        defaults.set(["true", "false"], forKey: LegacyPreferenceKeys.tutorialCompletionKey)
        defaults.set(LegacyChecklistParser.tutorialSentinel, forKey: LegacyPreferenceKeys.lastLoadedListKey)

        let container = try ModelContainerFactory.makeInMemory()
        let context = container.mainContext
        let result = try LegacyChecklistMigrator(context: context, defaults: defaults).migrateIfNeeded()
        let lists = try context.fetch(FetchDescriptor<Checklist>()).sorted(by: ChecklistOrderer.checklistSort)

        #expect(lists.map(\.name) == ["Checklist", "Checklist 2"])
        #expect(lists[1].items.map(\.title) == ["Tutorial custom task"])
        #expect(result.selectedChecklistID == lists[1].id)
    }
}
