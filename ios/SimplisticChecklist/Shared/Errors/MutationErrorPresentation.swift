import Foundation

/// Converts mutation failures into stable, user-presentable alert state.
/// Views share this adapter so fallback copy and localization stay consistent.
struct MutationErrorPresentation: Identifiable {
    let id = UUID()
    let message: String

    init(error: Error) {
        let localized = error.localizedDescription
            .trimmingCharacters(in: .whitespacesAndNewlines)
        message = localized.isEmpty
            ? String(localized: "The change could not be saved. Please try again.")
            : localized
    }
}
