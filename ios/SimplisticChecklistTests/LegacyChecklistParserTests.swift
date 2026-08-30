import Foundation
import Testing
@testable import SimplisticChecklist

@Suite("Legacy Flutter preference migration")
struct LegacyChecklistParserTests {
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
}
