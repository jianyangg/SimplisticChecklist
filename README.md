# Simplistic Checklist

## Introduction

Simplistic Checklist is a focused, local-first checklist for people who want
the essential task workflow without the complexity of Reminders.

## Native iOS development

The shipped app is now a native SwiftUI/SwiftData project. Open
`ios/SimplisticChecklist.xcodeproj` in Xcode and use the shared
`SimplisticChecklist` scheme. The project targets iOS 17 and later, uses Swift
6 with complete concurrency checking, and has no CocoaPods or third-party
dependencies.

The focused workflow includes inline and multi-line entry, completion, editing,
manual ordering, moving items between lists, list duplication, undo/redo, and
plain-text sharing. Completed-item visibility is remembered per checklist;
secondary actions remain in native menus so adding an item stays the one
obvious primary action.

The former Flutter implementation is preserved in
[`Legacy/FlutterApp`](Legacy/FlutterApp) for migration and historical
reference. Existing Flutter `shared_preferences` data is imported once into
the native store; the archive is not part of the native build and downgrade to
the old Flutter app is unsupported. See
[`docs/NATIVE_SWIFT_MIGRATION_PLAN.md`](docs/NATIVE_SWIFT_MIGRATION_PLAN.md)
for the full product, migration, design, and verification plan.

### Deterministic UI-test launch modes

The UI-test target can launch the app with explicit arguments:

- `--ui-testing-in-memory` starts a fresh, empty in-memory store.
- `--ui-testing-persistent` uses a named on-device test store so a relaunch
  verifies persistence; add `--ui-testing-reset-persistent` to clear that
  test-only store before a run.
- `--ui-testing-seeded-legacy` starts an in-memory store with representative
  Flutter `shared_preferences` values so the migration flow can be exercised.

These switches are test fixtures only. A normal launch uses the production
SwiftData store and the preserved legacy preferences.
