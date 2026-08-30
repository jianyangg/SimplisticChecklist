import Foundation
import SwiftData

/// A durable marker for a completed import from Flutter's shared preferences.
///
/// This lives in the native store instead of only in `UserDefaults` so a
/// missing or recreated native store can still be populated from the legacy
/// values that are intentionally retained for recovery.
@Model
final class ChecklistMigrationReceipt {
    static let flutterSharedPreferencesV1Identifier = "flutter.shared-preferences.v1"

    @Attribute(.unique) var id: String
    var sourceVersion: String
    var completedAt: Date
    var selectedChecklistID: UUID?

    init(
        id: String = ChecklistMigrationReceipt.flutterSharedPreferencesV1Identifier,
        sourceVersion: String = "1",
        completedAt: Date = .now,
        selectedChecklistID: UUID? = nil
    ) {
        self.id = id
        self.sourceVersion = sourceVersion
        self.completedAt = completedAt
        self.selectedChecklistID = selectedChecklistID
    }
}
