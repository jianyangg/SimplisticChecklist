import SwiftUI

enum ChecklistStrings {
    /// The interpolated integer is carried as a localized format argument.
    /// The catalog supplies the locale-specific plural variant.
    static func remaining(_ count: Int) -> LocalizedStringKey {
        "\(count) item remaining"
    }

    // LocalizedStringKey is not Sendable on current SwiftUI SDKs. Computed
    // properties avoid sharing a non-Sendable value under Swift 6 strict
    // concurrency while preserving the same catalog-backed keys.
    static var allItemsComplete: LocalizedStringKey { "All items complete" }
    static var noItemsYet: LocalizedStringKey { "No Items Yet" }

    static func itemsToAdd(_ count: Int) -> LocalizedStringKey {
        "\(count) items to add"
    }

    static func deleteListMessage(for name: String) -> String {
        String(
            localized: "\"\(name)\" and all of its items will be deleted.",
            comment: "Confirmation message for deleting a checklist."
        )
    }

    static func itemCompletionLabel(for title: String, isCompleted: Bool) -> String {
        if isCompleted {
            return String(
                localized: "Mark \(title) incomplete",
                comment: "Accessibility label for uncompleting a checklist item."
            )
        }
        return String(
            localized: "Mark \(title) complete",
            comment: "Accessibility label for completing a checklist item."
        )
    }
}
