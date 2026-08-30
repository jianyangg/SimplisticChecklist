import SwiftUI

enum ChecklistStrings {
    /// The interpolated integer is carried as a localized format argument.
    /// The catalog supplies the locale-specific plural variant.
    static func remaining(_ count: Int) -> LocalizedStringKey {
        "\(count) item remaining"
    }

    static let allItemsComplete: LocalizedStringKey = "All items complete"
}
