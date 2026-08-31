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

        let legacyValuesBefore = [
            LegacyPreferenceKeys.masterChecklistKey: defaults.object(forKey: LegacyPreferenceKeys.masterChecklistKey),
            LegacyPreferenceKeys.itemKey(for: "Work"): defaults.object(forKey: LegacyPreferenceKeys.itemKey(for: "Work")),
            LegacyPreferenceKeys.completionKey(for: "Work"): defaults.object(forKey: LegacyPreferenceKeys.completionKey(for: "Work")),
            LegacyPreferenceKeys.itemKey(for: "Errands"): defaults.object(forKey: LegacyPreferenceKeys.itemKey(for: "Errands")),
            LegacyPreferenceKeys.completionKey(for: "Errands"): defaults.object(forKey: LegacyPreferenceKeys.completionKey(for: "Errands")),
            LegacyPreferenceKeys.lastLoadedListKey: defaults.object(forKey: LegacyPreferenceKeys.lastLoadedListKey)
        ]

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
        for (key, value) in legacyValuesBefore {
            #expect(defaults.object(forKey: key) as? NSObject == value as? NSObject)
        }
        #expect(try context.fetch(FetchDescriptor<ChecklistMigrationReceipt>()).count == 1)

        // A fresh migrator instance represents a second launch against the
        // same native store. The durable receipt must prevent duplication.
        let secondResult = try LegacyChecklistMigrator(context: context, defaults: defaults)
            .migrateIfNeeded()
        #expect(!secondResult.imported)
        #expect(secondResult.selectedChecklistID == firstResult.selectedChecklistID)
        #expect(try context.fetch(FetchDescriptor<Checklist>()).count == 2)
        #expect(try context.fetch(FetchDescriptor<ChecklistMigrationReceipt>()).count == 1)
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

    @Test("restores selection for a whitespace-only legacy list name")
    func restoresWhitespaceListSelection() throws {
        let suiteName = "SimplisticChecklistTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        defaults.set(["First", "   "], forKey: LegacyPreferenceKeys.masterChecklistKey)
        defaults.set(["First task"], forKey: LegacyPreferenceKeys.itemKey(for: "First"))
        defaults.set(["Recovered task"], forKey: LegacyPreferenceKeys.itemKey(for: "   "))
        defaults.set("   ", forKey: LegacyPreferenceKeys.lastLoadedListKey)

        let container = try ModelContainerFactory.makeInMemory()
        let context = container.mainContext
        let result = try LegacyChecklistMigrator(context: context, defaults: defaults).migrateIfNeeded()
        let lists = try context.fetch(FetchDescriptor<Checklist>()).sorted(by: ChecklistOrderer.checklistSort)

        #expect(lists.map(\.name) == ["First", "Untitled List"])
        #expect(result.selectedChecklistID == lists[1].id)
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

    @Test("creates one empty checklist when no legacy keys exist")
    func createsDefaultForFreshInstall() throws {
        let suiteName = "SimplisticChecklistTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let container = try ModelContainerFactory.makeInMemory()
        let context = container.mainContext
        let result = try LegacyChecklistMigrator(context: context, defaults: defaults).migrateIfNeeded()
        let lists = try context.fetch(FetchDescriptor<Checklist>()).sorted(by: ChecklistOrderer.checklistSort)

        #expect(!result.imported)
        #expect(lists.map(\.name) == ["Checklist"])
        #expect(lists[0].items.isEmpty)
        #expect(try context.fetch(FetchDescriptor<ChecklistMigrationReceipt>()).count == 1)
    }

    @Test("imports an empty custom list instead of replacing it with the default")
    func preservesEmptyCustomList() throws {
        let suiteName = "SimplisticChecklistTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(["Empty"], forKey: LegacyPreferenceKeys.masterChecklistKey)

        let container = try ModelContainerFactory.makeInMemory()
        let context = container.mainContext
        let result = try LegacyChecklistMigrator(context: context, defaults: defaults).migrateIfNeeded()
        let lists = try context.fetch(FetchDescriptor<Checklist>()).sorted(by: ChecklistOrderer.checklistSort)

        #expect(result.imported)
        #expect(lists.map(\.name) == ["Empty"])
        #expect(lists[0].items.isEmpty)
    }

    @Test("imports a list with missing items without crashing")
    func preservesListWithMissingItems() throws {
        let suiteName = "SimplisticChecklistTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(["Missing Items"], forKey: LegacyPreferenceKeys.masterChecklistKey)
        defaults.set(["true"], forKey: LegacyPreferenceKeys.completionKey(for: "Missing Items"))

        let container = try ModelContainerFactory.makeInMemory()
        let context = container.mainContext
        let result = try LegacyChecklistMigrator(context: context, defaults: defaults).migrateIfNeeded()
        let list = try #require(context.fetch(FetchDescriptor<Checklist>()).first)

        #expect(result.imported)
        #expect(list.name == "Missing Items")
        #expect(list.items.isEmpty)
    }

    @Test("falls back to the first list when last selection is missing")
    func fallsBackWhenSelectionIsMissing() throws {
        let suiteName = "SimplisticChecklistTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(["First", "Second"], forKey: LegacyPreferenceKeys.masterChecklistKey)
        defaults.set(["one"], forKey: LegacyPreferenceKeys.itemKey(for: "First"))
        defaults.set(["two"], forKey: LegacyPreferenceKeys.itemKey(for: "Second"))

        let container = try ModelContainerFactory.makeInMemory()
        let context = container.mainContext
        let result = try LegacyChecklistMigrator(context: context, defaults: defaults).migrateIfNeeded()
        let lists = try context.fetch(FetchDescriptor<Checklist>()).sorted(by: ChecklistOrderer.checklistSort)

        #expect(result.selectedChecklistID == lists[0].id)
    }

    @Test("preserves a list whose name ends in the completion suffix")
    func preservesCompletionSuffixList() throws {
        let suiteName = "SimplisticChecklistTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(["Plan", "Plan_completion"], forKey: LegacyPreferenceKeys.masterChecklistKey)
        defaults.set(["Plan task"], forKey: LegacyPreferenceKeys.itemKey(for: "Plan"))
        // This key is both Plan's completion array and Plan_completion's text
        // array in the legacy format. The migrator should preserve both lists
        // and default Plan's ambiguous completion value to false.
        defaults.set(["Suffix task"], forKey: LegacyPreferenceKeys.itemKey(for: "Plan_completion"))
        defaults.set(["false"], forKey: LegacyPreferenceKeys.completionKey(for: "Plan_completion"))

        let container = try ModelContainerFactory.makeInMemory()
        let context = container.mainContext
        let result = try LegacyChecklistMigrator(context: context, defaults: defaults).migrateIfNeeded()
        let lists = try context.fetch(FetchDescriptor<Checklist>()).sorted(by: ChecklistOrderer.checklistSort)

        #expect(result.imported)
        #expect(lists.map(\.name) == ["Plan", "Plan_completion"])
        #expect(lists[0].items.map(\.title) == ["Plan task"])
        #expect(lists[0].items.map(\.isCompleted) == [false])
        #expect(lists[1].items.map(\.title) == ["Suffix task"])
    }

    @Test("preserves and selects a whitespace-padded tutorial sentinel list")
    func preservesPaddedTutorialSentinelList() throws {
        let suiteName = "SimplisticChecklistTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let paddedName = " \(LegacyChecklistParser.tutorialSentinel) "
        defaults.set([paddedName], forKey: LegacyPreferenceKeys.masterChecklistKey)
        defaults.set(["Saved task"], forKey: LegacyPreferenceKeys.itemKey(for: paddedName))
        defaults.set(["false"], forKey: LegacyPreferenceKeys.completionKey(for: paddedName))
        defaults.set(paddedName, forKey: LegacyPreferenceKeys.lastLoadedListKey)

        let container = try ModelContainerFactory.makeInMemory()
        let context = container.mainContext
        let result = try LegacyChecklistMigrator(context: context, defaults: defaults).migrateIfNeeded()
        let list = try #require(context.fetch(FetchDescriptor<Checklist>()).first)

        #expect(list.name == LegacyChecklistParser.tutorialSentinel)
        #expect(list.items.map(\.title) == ["Saved task"])
        #expect(result.selectedChecklistID == list.id)
    }

    @Test("does not resurrect an orphaned deleted list")
    func ignoresDeletedListOrphan() throws {
        let suiteName = "SimplisticChecklistTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(["Current"], forKey: LegacyPreferenceKeys.masterChecklistKey)
        defaults.set(["Current task"], forKey: LegacyPreferenceKeys.itemKey(for: "Current"))
        defaults.set(["false"], forKey: LegacyPreferenceKeys.completionKey(for: "Current"))
        defaults.set(["Ghost task"], forKey: LegacyPreferenceKeys.itemKey(for: "Deleted"))
        defaults.set(["true"], forKey: LegacyPreferenceKeys.completionKey(for: "Deleted"))

        let container = try ModelContainerFactory.makeInMemory()
        let context = container.mainContext
        _ = try LegacyChecklistMigrator(context: context, defaults: defaults).migrateIfNeeded()
        let lists = try context.fetch(FetchDescriptor<Checklist>()).sorted(by: ChecklistOrderer.checklistSort)

        #expect(lists.map(\.name) == ["Current"])
        #expect(lists[0].items.map(\.title) == ["Current task"])
    }

    @Test("does not seed untouched tutorial-only data")
    func doesNotSeedTutorialOnlyData() throws {
        let suiteName = "SimplisticChecklistTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set([
            "Welcome to Simplistic Checklist! Tap on the checkbox to mark an item as completed."
        ], forKey: LegacyPreferenceKeys.tutorialChecklistKey)
        defaults.set(["false"], forKey: LegacyPreferenceKeys.tutorialCompletionKey)
        defaults.set(LegacyChecklistParser.tutorialSentinel, forKey: LegacyPreferenceKeys.lastLoadedListKey)

        let container = try ModelContainerFactory.makeInMemory()
        let context = container.mainContext
        let result = try LegacyChecklistMigrator(context: context, defaults: defaults).migrateIfNeeded()
        let list = try #require(context.fetch(FetchDescriptor<Checklist>()).first)

        #expect(!result.imported)
        #expect(list.name == "Checklist")
        #expect(list.items.isEmpty)
    }

    @Test("preserves a partially written add-item state")
    func preservesPartialAddItemState() throws {
        let suiteName = "SimplisticChecklistTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(["Work"], forKey: LegacyPreferenceKeys.masterChecklistKey)
        defaults.set(["Existing", "New item"], forKey: LegacyPreferenceKeys.itemKey(for: "Work"))
        defaults.set([], forKey: LegacyPreferenceKeys.completionKey(for: "Work"))

        let container = try ModelContainerFactory.makeInMemory()
        let context = container.mainContext
        _ = try LegacyChecklistMigrator(context: context, defaults: defaults).migrateIfNeeded()
        let list = try #require(context.fetch(FetchDescriptor<Checklist>()).first)

        #expect(list.items.map(\.title) == ["Existing", "New item"])
        #expect(list.items.map(\.isCompleted) == [false, false])
    }

    @Test("leaves the source untouched when migration save fails and retries later")
    func retriesAfterSaveFailure() throws {
        let suiteName = "SimplisticChecklistTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(["Work"], forKey: LegacyPreferenceKeys.masterChecklistKey)
        defaults.set(["Ship report"], forKey: LegacyPreferenceKeys.itemKey(for: "Work"))
        defaults.set(["false"], forKey: LegacyPreferenceKeys.completionKey(for: "Work"))

        let schema = Schema(versionedSchema: ChecklistSchemaV1.self)
        let configuration = ModelConfiguration(
            "MigrationFailure-\(UUID().uuidString)",
            schema: schema,
            isStoredInMemoryOnly: true,
            allowsSave: false,
            groupContainer: .none,
            cloudKitDatabase: .none
        )
        let failingContainer = try ModelContainer(
            for: schema,
            migrationPlan: ChecklistSchemaMigrationPlan.self,
            configurations: [configuration]
        )

        #expect(throws: ChecklistMutationError.self) {
            try LegacyChecklistMigrator(
                context: failingContainer.mainContext,
                defaults: defaults
            ).migrateIfNeeded()
        }
        #expect(!defaults.bool(forKey: LegacyPreferenceKeys.nativeMigrationCompleted))
        #expect(try failingContainer.mainContext.fetch(FetchDescriptor<Checklist>()).isEmpty)
        #expect(try failingContainer.mainContext.fetch(FetchDescriptor<ChecklistMigrationReceipt>()).isEmpty)

        let retryContainer = try ModelContainerFactory.makeInMemory()
        let retryResult = try LegacyChecklistMigrator(
            context: retryContainer.mainContext,
            defaults: defaults
        ).migrateIfNeeded()
        let retryList = try #require(retryContainer.mainContext.fetch(FetchDescriptor<Checklist>()).first)

        #expect(retryResult.imported)
        #expect(retryList.name == "Work")
        #expect(retryList.items.map(\.title) == ["Ship report"])
        #expect(defaults.bool(forKey: LegacyPreferenceKeys.nativeMigrationCompleted))
    }
}
