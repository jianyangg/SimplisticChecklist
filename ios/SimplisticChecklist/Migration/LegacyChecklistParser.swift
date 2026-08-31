import Foundation

struct LegacyItemImport: Equatable {
    let title: String
    let isCompleted: Bool
}

struct LegacyChecklistImport: Equatable {
    enum Source: Equatable {
        case namedList
        case recoveredTutorialItems
    }

    /// Original preference-key component, retained only to resolve the
    /// previously selected list even when its display name needs recovery.
    let legacyName: String
    let name: String
    let items: [LegacyItemImport]
    let source: Source
}

struct LegacyImportDiagnostics: Equatable {
    var skippedListNames = 0
    var skippedItemValues = 0
    var invalidCompletionValues = 0
    var ignoredCompletionValues = 0
    var usedFallbackNames = 0
}

struct LegacyImportPlan: Equatable {
    let lists: [LegacyChecklistImport]
    let lastLoadedListName: String?
    let diagnostics: LegacyImportDiagnostics

    var hasRecoverableData: Bool {
        !lists.isEmpty
    }
}

struct LegacyChecklistParser {
    static let tutorialSentinel = LegacyPreferenceKeys.tutorialChecklist

    static let tutorialItemTitles: Set<String> = [
        "Welcome to Simplistic Checklist! Tap on the checkbox to mark an item as completed.",
        "Tap on the trash icon to delete the list. However, you cannot do this for the main list.",
        "Swipe from the right to delete an item from the list. Try it on this item!",
        "Tap on the add button to add a new item to the list.",
        "Tap on the refresh button to reset completed items.",
        "Tap on the menu button on the top left to switch between lists and add new lists.",
        "Completed items will be shown with a strikethrough and moved to the bottom of the list."
    ]

    func parse(from reader: any LegacyPreferenceReading) -> LegacyImportPlan {
        var diagnostics = LegacyImportDiagnostics()
        var imports: [LegacyChecklistImport] = []

        // The Flutter app used shared_preferences' default `flutter.` prefix.
        // Read only those namespaced keys so unrelated native/user defaults
        // cannot be mistaken for legacy checklist data during migration.
        let rawListNames = arrayValue(
            reader.value(forKey: LegacyPreferenceKeys.masterChecklistKey)
        )

        for rawListName in rawListNames {
            guard let listName = rawListName as? String else {
                diagnostics.skippedListNames += 1
                continue
            }

            // The tutorial checklist is stored separately from the user list
            // names. Treating it as a normal named list would import all seven
            // tutorial prompts into native data.
            if listName == Self.tutorialSentinel {
                continue
            }

            let displayName = normalizedLegacyName(listName, diagnostics: &diagnostics)
            guard let displayName else { continue }
            let items = parseItems(
                textValue: reader.value(forKey: LegacyPreferenceKeys.itemKey(for: listName)),
                completionValue: reader.value(forKey: LegacyPreferenceKeys.completionKey(for: listName)),
                diagnostics: &diagnostics
            )
            imports.append(LegacyChecklistImport(
                legacyName: listName,
                name: displayName,
                items: items,
                source: .namedList
            ))
        }

        let tutorialItems = parseItems(
            textValue: reader.value(forKey: LegacyPreferenceKeys.tutorialChecklistKey),
            completionValue: reader.value(forKey: LegacyPreferenceKeys.tutorialCompletionKey),
            diagnostics: &diagnostics
        )
        let customTutorialItems = tutorialItems.filter { !Self.tutorialItemTitles.contains($0.title) }
        if !customTutorialItems.isEmpty {
            imports.append(LegacyChecklistImport(
                legacyName: Self.tutorialSentinel,
                name: "Checklist",
                items: customTutorialItems,
                source: .recoveredTutorialItems
            ))
        }

        let lastLoadedListName = stringValue(
            reader.value(forKey: LegacyPreferenceKeys.lastLoadedListKey)
        )

        return LegacyImportPlan(
            lists: imports,
            lastLoadedListName: lastLoadedListName,
            diagnostics: diagnostics
        )
    }

    private func parseItems(
        textValue: Any?,
        completionValue: Any?,
        diagnostics: inout LegacyImportDiagnostics
    ) -> [LegacyItemImport] {
        let rawTexts = arrayValue(textValue)
        guard !rawTexts.isEmpty else { return [] }
        let rawCompletions = arrayValue(completionValue)

        var items: [LegacyItemImport] = []
        items.reserveCapacity(rawTexts.count)

        for (index, rawText) in rawTexts.enumerated() {
            guard let title = rawText as? String else {
                diagnostics.skippedItemValues += 1
                continue
            }

            let completion: Bool
            if index < rawCompletions.count {
                if let parsed = parseCompletion(rawCompletions[index]) {
                    completion = parsed
                } else {
                    completion = false
                    diagnostics.invalidCompletionValues += 1
                }
            } else {
                completion = false
            }
            items.append(LegacyItemImport(title: title, isCompleted: completion))
        }

        if rawCompletions.count > rawTexts.count {
            diagnostics.ignoredCompletionValues += rawCompletions.count - rawTexts.count
        }
        return items
    }

    private func normalizedLegacyName(
        _ name: String,
        diagnostics: inout LegacyImportDiagnostics
    ) -> String? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            diagnostics.usedFallbackNames += 1
            return String(localized: "Untitled List")
        }
        return trimmed
    }

    private func parseCompletion(_ value: Any) -> Bool? {
        guard let string = value as? String else { return nil }
        // Flutter persisted the literal strings "true" and "false". Do not
        // trim here: whitespace indicates a malformed value and should be
        // diagnosed rather than silently changing the user's data.
        switch string.lowercased() {
        case "true": return true
        case "false": return false
        default: return nil
        }
    }

    private func arrayValue(_ value: Any?) -> [Any] {
        if let strings = value as? [String] { return strings }
        if let values = value as? [Any] { return values }
        if let nsArray = value as? NSArray { return nsArray.map { $0 } }
        return []
    }

    private func stringValue(_ value: Any?) -> String? {
        value as? String
    }
}
