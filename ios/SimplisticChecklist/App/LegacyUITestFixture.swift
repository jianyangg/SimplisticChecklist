import Foundation

/// A small, representative Flutter preference fixture for the migration UI
/// path. It intentionally uses the exact `flutter.` keys written by
/// `shared_preferences`, while leaving every source value available for the
/// migrator to read and preserve.
enum LegacyUITestFixture {
    static func seed(into defaults: UserDefaults) {
        defaults.removePersistentDomain(forName: ChecklistLaunchConfiguration.uiTestingDefaultsSuite)
        defaults.set(
            ["Migrated Work", "Migrated Personal"],
            forKey: LegacyPreferenceKeys.masterChecklistKey
        )
        defaults.set(
            ["Review the migration", "Keep this task"],
            forKey: LegacyPreferenceKeys.itemKey(for: "Migrated Work")
        )
        defaults.set(
            ["false", "true"],
            forKey: LegacyPreferenceKeys.completionKey(for: "Migrated Work")
        )
        defaults.set(
            ["Buy groceries"],
            forKey: LegacyPreferenceKeys.itemKey(for: "Migrated Personal")
        )
        defaults.set(
            ["false"],
            forKey: LegacyPreferenceKeys.completionKey(for: "Migrated Personal")
        )
        defaults.set("Migrated Personal", forKey: LegacyPreferenceKeys.lastLoadedListKey)

        // The native receipt and selection are deliberately absent: this
        // launch must exercise the first-run migration path every time.
        defaults.removeObject(forKey: LegacyPreferenceKeys.nativeMigrationCompleted)
        defaults.removeObject(forKey: LegacyPreferenceKeys.nativeSelectedChecklistID)
    }
}
