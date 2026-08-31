import Foundation
import Testing
@testable import SimplisticChecklist

@Suite("Legacy Flutter preference migration")
struct LegacyChecklistParserTests {
    @Test("returns an empty plan when no legacy keys exist")
    func handlesNoLegacyKeys() {
        let plan = LegacyChecklistParser().parse(
            from: DictionaryLegacyPreferenceReader(values: [:])
        )

        #expect(plan.lists.isEmpty)
        #expect(plan.lastLoadedListName == nil)
        #expect(!plan.hasRecoverableData)
    }

    @Test("treats a malformed master-list value as empty")
    func handlesMalformedMasterListValue() {
        let reader = DictionaryLegacyPreferenceReader(values: [
            LegacyPreferenceKeys.masterChecklistKey: "not an array",
            LegacyPreferenceKeys.lastLoadedListKey: 42
        ])

        let plan = LegacyChecklistParser().parse(from: reader)

        #expect(plan.lists.isEmpty)
        #expect(plan.lastLoadedListName == nil)
    }

    @Test("imports named lists, completion state, and last selection")
    func importsNamedLists() {
        let reader = DictionaryLegacyPreferenceReader(values: [
            LegacyPreferenceKeys.masterChecklistKey: ["Work", "Errands"],
            LegacyPreferenceKeys.itemKey(for: "Work"): ["Ship report", "Call bank"],
            LegacyPreferenceKeys.completionKey(for: "Work"): ["false", "true"],
            LegacyPreferenceKeys.itemKey(for: "Errands"): ["Buy milk"],
            LegacyPreferenceKeys.completionKey(for: "Errands"): ["false"],
            LegacyPreferenceKeys.lastLoadedListKey: "Errands"
        ])

        let plan = LegacyChecklistParser().parse(from: reader)

        #expect(plan.lists.map(\.name) == ["Work", "Errands"])
        #expect(plan.lists[0].items.map(\.title) == ["Ship report", "Call bank"])
        #expect(plan.lists[0].items.map(\.isCompleted) == [false, true])
        #expect(plan.lastLoadedListName == "Errands")
    }

    @Test("keeps a valid custom list even when it has no items")
    func importsEmptyCustomList() {
        let reader = DictionaryLegacyPreferenceReader(values: [
            LegacyPreferenceKeys.masterChecklistKey: ["Empty"]
        ])

        let plan = LegacyChecklistParser().parse(from: reader)

        #expect(plan.lists.map(\.name) == ["Empty"])
        #expect(plan.lists[0].items.isEmpty)
        #expect(plan.hasRecoverableData)
    }

    @Test("tolerates a missing item array and ignores an orphan completion array")
    func handlesMissingItemArray() {
        let reader = DictionaryLegacyPreferenceReader(values: [
            LegacyPreferenceKeys.masterChecklistKey: ["Missing Items"],
            LegacyPreferenceKeys.completionKey(for: "Missing Items"): ["true"]
        ])

        let plan = LegacyChecklistParser().parse(from: reader)

        #expect(plan.lists.map(\.name) == ["Missing Items"])
        #expect(plan.lists[0].items.isEmpty)
        #expect(plan.diagnostics.invalidCompletionValues == 0)
    }

    @Test("defaults every item to incomplete when its completion array is missing")
    func handlesMissingCompletionArray() {
        let reader = DictionaryLegacyPreferenceReader(values: [
            LegacyPreferenceKeys.masterChecklistKey: ["Missing Completion"],
            LegacyPreferenceKeys.itemKey(for: "Missing Completion"): ["One", "Two"]
        ])

        let plan = LegacyChecklistParser().parse(from: reader)

        #expect(plan.lists[0].items.map(\.isCompleted) == [false, false])
        #expect(plan.diagnostics.invalidCompletionValues == 0)
    }

    @Test("defaults missing and malformed completion values to incomplete")
    func handlesMalformedCompletion() {
        let reader = DictionaryLegacyPreferenceReader(values: [
            LegacyPreferenceKeys.masterChecklistKey: ["Work"],
            LegacyPreferenceKeys.itemKey(for: "Work"): ["One", "Two", "Three"],
            LegacyPreferenceKeys.completionKey(for: "Work"): ["TRUE", "unknown"]
        ])

        let plan = LegacyChecklistParser().parse(from: reader)
        #expect(plan.lists[0].items.map(\.isCompleted) == [true, false, false])
        #expect(plan.diagnostics.invalidCompletionValues == 1)
    }

    @Test("recovers custom tutorial items but does not seed tutorial copy")
    func recoversTutorialCustomItems() {
        let reader = DictionaryLegacyPreferenceReader(values: [
            LegacyPreferenceKeys.tutorialChecklistKey: [
                "Welcome to Simplistic Checklist! Tap on the checkbox to mark an item as completed.",
                "My saved task"
            ],
            LegacyPreferenceKeys.tutorialCompletionKey: ["true", "false"],
            LegacyPreferenceKeys.lastLoadedListKey: LegacyPreferenceKeys.tutorialChecklist
        ])

        let plan = LegacyChecklistParser().parse(from: reader)
        #expect(plan.lists.count == 1)
        #expect(plan.lists[0].name == "Checklist")
        #expect(plan.lists[0].items.map(\.title) == ["My saved task"])
        #expect(plan.lastLoadedListName == LegacyPreferenceKeys.tutorialChecklist)
    }

    @Test("tolerates short and extra completion arrays")
    func handlesMismatchedArrays() {
        let reader = DictionaryLegacyPreferenceReader(values: [
            LegacyPreferenceKeys.masterChecklistKey: ["Work"],
            LegacyPreferenceKeys.itemKey(for: "Work"): ["One"],
            LegacyPreferenceKeys.completionKey(for: "Work"): ["false", "true"]
        ])

        let plan = LegacyChecklistParser().parse(from: reader)
        #expect(plan.lists[0].items.count == 1)
        #expect(plan.diagnostics.ignoredCompletionValues == 1)
    }

    @Test("preserves stable indexes across short and long completion arrays")
    func handlesBothCompletionLengths() {
        let reader = DictionaryLegacyPreferenceReader(values: [
            LegacyPreferenceKeys.masterChecklistKey: ["Short", "Long"],
            LegacyPreferenceKeys.itemKey(for: "Short"): ["One", "Two"],
            LegacyPreferenceKeys.completionKey(for: "Short"): ["true"],
            LegacyPreferenceKeys.itemKey(for: "Long"): ["A", "B"],
            LegacyPreferenceKeys.completionKey(for: "Long"): ["false", "true", "false"]
        ])

        let plan = LegacyChecklistParser().parse(from: reader)

        #expect(plan.lists[0].items.map(\.isCompleted) == [true, false])
        #expect(plan.lists[1].items.map(\.isCompleted) == [false, true])
        #expect(plan.diagnostics.ignoredCompletionValues == 1)
    }

    @Test("rejects malformed Boolean strings without crashing")
    func handlesInvalidCompletionValues() {
        let reader = DictionaryLegacyPreferenceReader(values: [
            LegacyPreferenceKeys.masterChecklistKey: ["Invalid Booleans"],
            LegacyPreferenceKeys.itemKey(for: "Invalid Booleans"): [
                "Upper", "Lower", "Number", "Word", "Empty", "Whitespace"
            ],
            LegacyPreferenceKeys.completionKey(for: "Invalid Booleans"): [
                "TRUE", "false", "1", "yes", "", " true "
            ]
        ])

        let plan = LegacyChecklistParser().parse(from: reader)

        #expect(plan.lists[0].items.map(\.isCompleted) == [true, false, false, false, false, false])
        #expect(plan.diagnostics.invalidCompletionValues == 4)
    }

    @Test("skips malformed list and item values while preserving valid values")
    func handlesMalformedArrays() {
        let reader = DictionaryLegacyPreferenceReader(values: [
            LegacyPreferenceKeys.masterChecklistKey: ["Good", 42, "   "],
            LegacyPreferenceKeys.itemKey(for: "Good"): ["Valid", 42, "Also valid"],
            LegacyPreferenceKeys.completionKey(for: "Good"): ["false", "true", "false"]
        ])

        let plan = LegacyChecklistParser().parse(from: reader)

        #expect(plan.lists.map(\.name) == ["Good", "Untitled List"])
        #expect(plan.lists[0].items.map(\.title) == ["Valid", "Also valid"])
        #expect(plan.lists[0].items.map(\.isCompleted) == [false, false])
        #expect(plan.diagnostics.skippedListNames == 1)
        #expect(plan.diagnostics.skippedItemValues == 1)
    }

    @Test("keeps whitespace-only names recoverable with a fallback name")
    func keepsWhitespaceListName() {
        let reader = DictionaryLegacyPreferenceReader(values: [
            LegacyPreferenceKeys.masterChecklistKey: ["   "],
            LegacyPreferenceKeys.itemKey(for: "   "): ["Saved task"]
        ])

        let plan = LegacyChecklistParser().parse(from: reader)

        #expect(plan.lists.map(\.name) == ["Untitled List"])
        #expect(plan.lists[0].items.map(\.title) == ["Saved task"])
        #expect(plan.diagnostics.usedFallbackNames == 1)
    }

    @Test("keeps names ending in the completion suffix recoverable")
    func handlesCompletionSuffixName() {
        let reader = DictionaryLegacyPreferenceReader(values: [
            LegacyPreferenceKeys.masterChecklistKey: ["Plan", "Plan_completion"],
            LegacyPreferenceKeys.itemKey(for: "Plan"): ["Plan task"],
            // This key is both Plan's legacy completion key and the item key
            // for Plan_completion. The parser must remain safe and preserve
            // the suffix-named list's task instead of treating it as a key.
            LegacyPreferenceKeys.itemKey(for: "Plan_completion"): ["Suffix task"],
            LegacyPreferenceKeys.completionKey(for: "Plan_completion"): ["false"]
        ])

        let plan = LegacyChecklistParser().parse(from: reader)

        #expect(plan.lists.map(\.name) == ["Plan", "Plan_completion"])
        #expect(plan.lists[0].items.map(\.title) == ["Plan task"])
        #expect(plan.lists[0].items.map(\.isCompleted) == [false])
        #expect(plan.lists[1].items.map(\.title) == ["Suffix task"])
        #expect(plan.diagnostics.invalidCompletionValues == 1)
    }

    @Test("ignores orphan list keys that are absent from the master list")
    func ignoresOrphanKeys() {
        let reader = DictionaryLegacyPreferenceReader(values: [
            LegacyPreferenceKeys.masterChecklistKey: ["Current"],
            LegacyPreferenceKeys.itemKey(for: "Current"): ["Current task"],
            LegacyPreferenceKeys.completionKey(for: "Current"): ["false"],
            LegacyPreferenceKeys.itemKey(for: "Deleted"): ["Ghost task"],
            LegacyPreferenceKeys.completionKey(for: "Deleted"): ["true"]
        ])

        let plan = LegacyChecklistParser().parse(from: reader)

        #expect(plan.lists.map(\.name) == ["Current"])
        #expect(plan.lists[0].items.map(\.title) == ["Current task"])
    }

    @Test("does not seed tutorial copy when only the untouched tutorial exists")
    func handlesTutorialOnlyData() {
        let reader = DictionaryLegacyPreferenceReader(values: [
            LegacyPreferenceKeys.tutorialChecklistKey: [
                "Welcome to Simplistic Checklist! Tap on the checkbox to mark an item as completed."
            ],
            LegacyPreferenceKeys.tutorialCompletionKey: ["false"],
            LegacyPreferenceKeys.lastLoadedListKey: LegacyChecklistParser.tutorialSentinel
        ])

        let plan = LegacyChecklistParser().parse(from: reader)

        #expect(plan.lists.isEmpty)
        #expect(!plan.hasRecoverableData)
        #expect(plan.lastLoadedListName == LegacyChecklistParser.tutorialSentinel)
    }

    @Test("recovers custom tutorial items alongside tutorial copy")
    func handlesTutorialWithCustomItems() {
        let reader = DictionaryLegacyPreferenceReader(values: [
            LegacyPreferenceKeys.tutorialChecklistKey: [
                "Welcome to Simplistic Checklist! Tap on the checkbox to mark an item as completed.",
                "Saved while using the tutorial"
            ],
            LegacyPreferenceKeys.tutorialCompletionKey: ["true", "false"],
            LegacyPreferenceKeys.lastLoadedListKey: LegacyChecklistParser.tutorialSentinel
        ])

        let plan = LegacyChecklistParser().parse(from: reader)

        #expect(plan.lists.map(\.name) == ["Checklist"])
        #expect(plan.lists[0].source == .recoveredTutorialItems)
        #expect(plan.lists[0].items.map(\.title) == ["Saved while using the tutorial"])
    }

    @Test("recovers a partially written add-item state with an empty completion array")
    func handlesPartiallyWrittenAddItem() {
        let reader = DictionaryLegacyPreferenceReader(values: [
            LegacyPreferenceKeys.masterChecklistKey: ["Work"],
            LegacyPreferenceKeys.itemKey(for: "Work"): ["Existing", "New item"],
            LegacyPreferenceKeys.completionKey(for: "Work"): []
        ])

        let plan = LegacyChecklistParser().parse(from: reader)

        #expect(plan.lists[0].items.map(\.title) == ["Existing", "New item"])
        #expect(plan.lists[0].items.map(\.isCompleted) == [false, false])
        #expect(plan.diagnostics.invalidCompletionValues == 0)
    }

    @Test("reads only Flutter-prefixed keys")
    func ignoresUnprefixedLookalikes() {
        let reader = DictionaryLegacyPreferenceReader(values: [
            LegacyPreferenceKeys.masterChecklistKey: ["Work"],
            LegacyPreferenceKeys.itemKey(for: "Work"): ["Correct source"],
            LegacyPreferenceKeys.completionKey(for: "Work"): ["false"],
            LegacyPreferenceKeys.masterChecklist: ["Should not import"],
            "Work": ["Wrong source"],
            "Work_completion": ["true"],
            LegacyPreferenceKeys.tutorialChecklist: ["Unprefixed tutorial edit"],
            "\(LegacyPreferenceKeys.tutorialChecklist)_completion": ["false"],
            LegacyPreferenceKeys.lastLoadedList: "Should not select"
        ])

        let plan = LegacyChecklistParser().parse(from: reader)

        #expect(plan.lists.map(\.name) == ["Work"])
        #expect(plan.lists[0].items.map(\.title) == ["Correct source"])
        #expect(plan.lists[0].items.map(\.isCompleted) == [false])
        #expect(plan.lastLoadedListName == nil)
    }

    @Test("imports a whitespace-padded tutorial sentinel as a user list")
    func importsPaddedTutorialSentinelAsUserList() {
        let paddedName = " \(LegacyChecklistParser.tutorialSentinel) "
        let reader = DictionaryLegacyPreferenceReader(values: [
            LegacyPreferenceKeys.masterChecklistKey: [paddedName],
            LegacyPreferenceKeys.itemKey(for: paddedName): ["Saved task"],
            LegacyPreferenceKeys.completionKey(for: paddedName): ["false"],
            LegacyPreferenceKeys.lastLoadedListKey: paddedName
        ])

        let plan = LegacyChecklistParser().parse(from: reader)

        #expect(plan.lists.count == 1)
        #expect(plan.lists[0].source == .namedList)
        #expect(plan.lists[0].name == LegacyChecklistParser.tutorialSentinel)
        #expect(plan.lists[0].items.map(\.title) == ["Saved task"])
        #expect(plan.lastLoadedListName == paddedName)
    }
}
