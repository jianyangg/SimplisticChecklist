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

The former Flutter implementation is preserved in
[`Legacy/FlutterApp`](Legacy/FlutterApp) for migration and historical
reference. Existing Flutter `shared_preferences` data is imported once into
the native store; the archive is not part of the native build and downgrade to
the old Flutter app is unsupported. See
[`docs/NATIVE_SWIFT_MIGRATION_PLAN.md`](docs/NATIVE_SWIFT_MIGRATION_PLAN.md)
for the full product, migration, design, and verification plan.
