import Foundation
import SwiftData

struct MigrationResult {
    let selectedChecklistID: UUID
    let imported: Bool
    let diagnostics: LegacyImportDiagnostics
}

@MainActor
final class LegacyChecklistMigrator {
    private let context: ModelContext
    private let defaults: UserDefaults
    private let parser: LegacyChecklistParser

    init(
        context: ModelContext,
        defaults: UserDefaults = .standard,
        parser: LegacyChecklistParser = LegacyChecklistParser()
    ) {
        self.context = context
        self.defaults = defaults
        self.parser = parser
    }

    func migrateIfNeeded() throws -> MigrationResult {
        let existing = try fetchChecklists()
        if let receipt = try fetchMigrationReceipt() {
            // The receipt is stored in the same SwiftData save as the imported
            // models. It is authoritative for this store; the UserDefaults
            // marker is retained only as a compatibility/debugging hint.
            guard !existing.isEmpty else {
                // A receipt without a checklist is an invalid native state,
                // but it is recoverable without rereading legacy values or
                // duplicating an import.
                let checklist = Checklist(name: String(localized: "Checklist"), sortOrder: 0)
                context.insert(checklist)
                receipt.selectedChecklistID = checklist.id
                try save()
                persistSelection(checklist.id)
                return MigrationResult(
                    selectedChecklistID: checklist.id,
                    imported: false,
                    diagnostics: .init()
                )
            }

            guard let selectedID = resolveExistingSelection(from: existing, receipt: receipt) else {
                throw ChecklistMutationError.checklistNotFound
            }
            receipt.selectedChecklistID = selectedID
            try save()
            persistSelection(selectedID)
            return MigrationResult(selectedChecklistID: selectedID, imported: false, diagnostics: .init())
        }

        if !existing.isEmpty {
            // Native data may have been created before the receipt (for
            // example, after a terminated launch). Never import legacy data
            // on top of it; establish a receipt for future idempotence.
            guard let selectedID = resolveExistingSelection(from: existing, receipt: nil) else {
                throw ChecklistMutationError.checklistNotFound
            }
            context.insert(ChecklistMigrationReceipt(selectedChecklistID: selectedID))
            try save()
            persistSelection(selectedID)
            return MigrationResult(selectedChecklistID: selectedID, imported: false, diagnostics: .init())
        }

        let plan = parser.parse(from: UserDefaultsLegacyPreferenceReader(defaults: defaults))
        let imports = mergedImports(plan.lists)

        if imports.isEmpty {
            let checklist = Checklist(name: String(localized: "Checklist"), sortOrder: 0)
            context.insert(checklist)
            context.insert(ChecklistMigrationReceipt(selectedChecklistID: checklist.id))
            try save()
            persistSelection(checklist.id)
            return MigrationResult(selectedChecklistID: checklist.id, imported: false, diagnostics: plan.diagnostics)
        }

        var inserted: [(displayName: String, legacyName: String, source: LegacyChecklistImport.Source, id: UUID)] = []
        var usedNames = Set<String>()

        for importedList in imports {
            let name = uniqueName(importedList.name, usedNames: &usedNames)
            let checklist = Checklist(name: name, sortOrder: inserted.count)
            context.insert(checklist)
            for (index, importedItem) in importedList.items.enumerated() {
                let item = ChecklistItem(
                    title: importedItem.title,
                    isCompleted: importedItem.isCompleted,
                    sortOrder: index
                )
                context.insert(item)
                checklist.items.append(item)
                item.checklist = checklist
            }
            inserted.append((
                displayName: name,
                legacyName: importedList.legacyName,
                source: importedList.source,
                id: checklist.id
            ))
        }

        guard let firstInsertedID = inserted.first?.id else {
            throw ChecklistMutationError.checklistNotFound
        }
        let selectedID = selectImportedChecklistID(
            lastLoadedListName: plan.lastLoadedListName,
            inserted: inserted
        ) ?? firstInsertedID

        context.insert(ChecklistMigrationReceipt(selectedChecklistID: selectedID))
        try save()
        persistSelection(selectedID)
        return MigrationResult(selectedChecklistID: selectedID, imported: true, diagnostics: plan.diagnostics)
    }

    private func fetchChecklists() throws -> [Checklist] {
        try context.fetch(FetchDescriptor<Checklist>()).sorted(by: ChecklistOrderer.checklistSort)
    }

    private func save() throws {
        do {
            try context.save()
        } catch {
            context.rollback()
            throw ChecklistMutationError.persistenceFailed(error.localizedDescription)
        }
    }

    private func fetchMigrationReceipt() throws -> ChecklistMigrationReceipt? {
        try context.fetch(FetchDescriptor<ChecklistMigrationReceipt>())
            .first(where: { $0.id == ChecklistMigrationReceipt.flutterSharedPreferencesV1Identifier })
    }

    private func resolveExistingSelection(
        from checklists: [Checklist],
        receipt: ChecklistMigrationReceipt?
    ) -> UUID? {
        if let receiptID = receipt?.selectedChecklistID,
           checklists.contains(where: { $0.id == receiptID }) {
            return receiptID
        }
        if let storedID = defaults.string(forKey: LegacyPreferenceKeys.nativeSelectedChecklistID),
           let id = UUID(uuidString: storedID),
           checklists.contains(where: { $0.id == id }) {
            return id
        }
        return checklists.sorted(by: ChecklistOrderer.checklistSort).first?.id
    }

    private func mergedImports(_ imports: [LegacyChecklistImport]) -> [LegacyChecklistImport] {
        var result: [LegacyChecklistImport] = []
        var recoveredTutorialItems: [LegacyItemImport] = []

        for imported in imports {
            if imported.source == .recoveredTutorialItems {
                recoveredTutorialItems.append(contentsOf: imported.items)
            } else {
                // Keep duplicate legacy names as separate lists. The old
                // format used names as keys and permitted case-only collisions;
                // uniqueName(_:) preserves each entry with a numeric suffix.
                result.append(imported)
            }
        }

        if !recoveredTutorialItems.isEmpty {
            // Keep recovered tutorial edits separate from a user-created list
            // that happens to be named “Checklist”. The writer will suffix
            // the recovered list when necessary, preserving both collections
            // and allowing the legacy tutorial selection to resolve exactly.
            result.append(LegacyChecklistImport(
                legacyName: LegacyChecklistParser.tutorialSentinel,
                name: String(localized: "Checklist"),
                items: recoveredTutorialItems,
                source: .recoveredTutorialItems
            ))
        }

        return result
    }

    private func selectImportedChecklistID(
        lastLoadedListName: String?,
        inserted: [(displayName: String, legacyName: String, source: LegacyChecklistImport.Source, id: UUID)]
    ) -> UUID? {
        guard let lastLoadedListName else { return nil }
        let normalizedSelection = lastLoadedListName.trimmingCharacters(in: .whitespacesAndNewlines)
        if lastLoadedListName == LegacyChecklistParser.tutorialSentinel {
            return inserted.first(where: {
                $0.source == .recoveredTutorialItems
            })?.id
        }

        // Prefer the exact legacy spelling before falling back to a
        // case-insensitive match. This preserves selection when old data has
        // names such as “Work” and “work”.
        if let exact = inserted.first(where: {
            $0.source == .namedList && $0.legacyName == lastLoadedListName
        }) {
            return exact.id
        }
        return inserted.first(where: {
            guard $0.source == .namedList else { return false }
            let normalizedLegacyName = $0.legacyName.trimmingCharacters(in: .whitespacesAndNewlines)
            return normalizedLegacyName.caseInsensitiveCompare(normalizedSelection) == .orderedSame
        })?.id
    }

    private func uniqueName(_ requested: String, usedNames: inout Set<String>) -> String {
        let base = requested.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? String(localized: "Untitled List")
            : requested.trimmingCharacters(in: .whitespacesAndNewlines)
        var candidate = base
        var suffix = 2
        while usedNames.contains(nameKey(candidate)) {
            candidate = "\(base) \(suffix)"
            suffix += 1
        }
        usedNames.insert(nameKey(candidate))
        return candidate
    }

    private func nameKey(_ name: String) -> String {
        name.folding(
            options: [.caseInsensitive, .diacriticInsensitive],
            locale: Locale(identifier: "en_US_POSIX")
        )
    }

    private func persistSelection(_ id: UUID) {
        defaults.set(true, forKey: LegacyPreferenceKeys.nativeMigrationCompleted)
        defaults.set(id.uuidString, forKey: LegacyPreferenceKeys.nativeSelectedChecklistID)
    }
}
