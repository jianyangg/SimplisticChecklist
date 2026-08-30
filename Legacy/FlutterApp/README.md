# Archived Flutter implementation

This directory is a read-only archive of the Flutter implementation that shipped
before the native Swift migration. It was archived from revision
`6041d60c3eebdf9450f877457fa5bd6e613d3d4c` on 2026-08-30.

The contents are not part of the shipped native Xcode project and must not be
compiled, embedded, or referenced by the native target. Keep this archive for
historical reference and for validating existing-user data migration.

## Legacy iOS storage keys

The native migrator reads the following `shared_preferences` / `UserDefaults`
keys from the legacy app:

- `flutter.masterChecklist7dL5&gK9q@2mF`: user-created list names (`[String]`)
- `flutter.<LIST_NAME>`: item text for a list (`[String]`)
- `flutter.<LIST_NAME>_completion`: completion values (`[String]`, containing
  `"true"` or `"false"`)
- `flutter.lastLoadedList`: last-selected list name (`String`)
- `flutter.main7dL5&gK9q@2mF`: tutorial-list item text (`[String]`), when the
  tutorial list was mutated
- `flutter.main7dL5&gK9q@2mF_completion`: tutorial-list completion values

List names were used directly as preference keys by the Flutter app. The native
importer must treat malformed, mismatched, and colliding values defensively and
must never delete the legacy values as part of migration.

## Downgrade policy

Downgrading from the native app to the archived Flutter app is unsupported. The
native SwiftData store is not a format that the archived Flutter implementation
can read. Users must remain on the native release after upgrading; the archive
exists for source and migration reference only.
