# Simplistic Checklist: Native Swift Migration Plan

Status: implementation complete; Xcode/device validation pending
Prepared: August 29, 2026
Current implementation: Flutter 3-era application from 2023
Target implementation: native SwiftUI and SwiftData application

## 1. Executive summary

Simplistic Checklist should become a focused, native Apple-platform checklist app for people who find Reminders more complicated than they need. Its purpose is not to compete feature-for-feature with Reminders. Its purpose is to make creating a list, adding an item, and checking it off exceptionally fast and reliable.

The native release will preserve the current product's essential capabilities:

- Multiple named checklists.
- Adding, completing, resetting, and deleting checklist items.
- Creating, selecting, and deleting lists.
- Remembering the user's lists, item completion, and last-selected list.

It will also add a small set of overdue fundamentals:

- Edit item text.
- Reorder items and lists.
- Rename lists.
- Clear completed items.
- Undo routine destructive actions.
- Proper empty, loading, migration, and storage-error states.
- Native accessibility, Dynamic Type, dark mode, keyboard, and adaptive iPad behavior.

The existing Flutter code will be archived in the repository and removed from the shipped product. The app will retain its current bundle identifier and include a one-time migration from Flutter's `shared_preferences` data to SwiftData so an App Store update does not erase existing users' tasks.

The app will remain local-first, private, dependency-free, and intentionally narrow. Version 1 of the native rewrite will not add reminders, due dates, recurrence, tags, subtasks, attachments, accounts, collaboration, or cloud sync.

## 2. Product definition

### 2.1 One-sentence user job

Open a checklist, add what needs doing, and check items off without configuring a task-management system.

### 2.2 Product promise

> A fast, calm checklist that stays out of the way.

### 2.3 Primary action and success state

- Entry point: the most recently used checklist.
- Primary action: add a checklist item inline.
- Supporting actions: complete, edit, reorder, and delete an item; switch or manage lists.
- Success state: the user can see what remains and can confidently close the app knowing it is saved.

### 2.4 Design principles

1. **Immediate utility:** launch into useful content, not a dashboard or onboarding flow.
2. **One obvious action:** adding an item is always the dominant action on a checklist screen.
3. **Progressive disclosure:** list administration and destructive actions live in menus or edit mode.
4. **Native familiarity:** use standard SwiftUI navigation, lists, menus, sheets, alerts, swipe actions, and text fields.
5. **Forgiveness:** ordinary deletion is undoable; truly destructive bulk actions require review.
6. **Content over decoration:** tasks are visually dominant; navigation and controls form a separate functional layer.
7. **Private by default:** no account, network request, analytics SDK, tracking, or data collection.
8. **Small feature budget:** every feature must shorten a common checklist workflow or prevent meaningful data loss.

### 2.5 What “modern” means for this app

Modern design does not mean layering custom glass, gradients, cards, and animation onto every element. It means:

- A clear hierarchy and predictable navigation model.
- System typography, SF Symbols, semantic colors, and standard spacing.
- System controls that automatically adopt the current platform appearance, including Liquid Glass on current OS releases.
- No custom backgrounds over navigation bars or toolbars that interfere with system materials.
- Smooth but restrained transitions that respect Reduce Motion.
- Interfaces that adapt from compact iPhone layouts to iPad split views.
- Full support for Dynamic Type, VoiceOver, increased contrast, reduced transparency, and keyboard navigation.
- Dark mode with semantic colors instead of fixed white, grey, and black values.

The app will build with the latest installed Xcode SDK while keeping an iOS 17 deployment floor. Standard SwiftUI components provide the current iOS 26 appearance automatically and retain an appropriate native appearance on iOS 17 and later. iOS 26-only polish will be availability-gated and must not create a separate interaction model on older supported versions.

## 3. Exhaustive current-state audit

### 3.1 Repository shape

The repository is a generated cross-platform Flutter project. The product-specific implementation is small, but it is surrounded by generated platform shells:

- `lib/main.dart`: Flutter application entry point and global Material theme.
- `lib/pages/home_page.dart`: approximately 750 lines containing nearly all UI, state, persistence, navigation, and validation logic.
- `lib/model/checklist_item.dart`: mutable checklist item model and seven tutorial items.
- `lib/widgets/checklist_item_tile.dart`: item row, completion tap, swipe-to-delete, and delete confirmation.
- `lib/constants/colours.dart`: fixed light-mode color values.
- `test/widget_test.dart`: unchanged Flutter counter-template test; it does not test this app.
- `assets/images/icon.png`: 1024×1024 source icon.
- `assets/images/quote.png`: 512×512 quote-mark asset.
- `ios/`: Flutter Runner project, Flutter build phases, CocoaPods integration, bridge header, storyboards, and generated plugin registration.
- `android/`, `web/`, `windows/`, `linux/`, and `macos/`: generated Flutter targets.
- `pubspec.yaml`: Flutter, Cupertino Icons, and `shared_preferences` dependencies.
- `README.md`: one-paragraph product motivation.

The working tree was clean at the time of this audit and the active branch was `main`. No branch will be switched as part of implementation without explicit approval.

### 3.2 Existing product behavior

#### App launch

- Starts with a built-in tutorial checklist in memory.
- Loads Flutter `shared_preferences` asynchronously.
- Attempts to restore user-created lists and the last-selected list.
- Always reconstructs the built-in tutorial list instead of reliably restoring changes made to it.

#### Checklist items

- An item has a string ID, optional text, and a completion Boolean.
- Tapping anywhere on the row toggles completion.
- Completed items are struck through and sorted below active items.
- Items are added through a modal text field.
- Items are deleted by swiping and then confirming in an alert.
- A toolbar action resets all items to incomplete after confirmation.
- Editing and reordering are noted as TODOs but are not implemented.

#### Lists

- User-created list names are shown in a left-side drawer.
- A list is created through a nested modal prompt.
- Exact duplicate list names are rejected.
- Selecting a user-created list closes the drawer and displays it.
- The special tutorial list cannot be deleted.
- A user-created list can be deleted after confirmation.
- The last-selected list name is persisted.

#### Presentation

- A Charlie Munger quote and quote-mark image appear above every checklist.
- Reset, add item, and delete list all occupy the top app bar.
- The current list name is not presented as a strong navigation title.
- List switching is hidden in the drawer.
- Checklist rows use white rounded cards on a fixed pale-grey background.

### 3.3 Legacy storage format

Flutter's `shared_preferences` uses `UserDefaults` on iOS and prefixes its default keys with `flutter.`. The current app stores:

| Logical value | Native `UserDefaults` key | Stored type |
| --- | --- | --- |
| User-created list names | `flutter.masterChecklist7dL5&gK9q@2mF` | `[String]` |
| Item text for a list named `NAME` | `flutter.NAME` | `[String]` |
| Completion values for `NAME` | `flutter.NAME_completion` | `[String]` containing `"true"` or `"false"` |
| Last-selected list | `flutter.lastLoadedList` | `String` |
| Special tutorial list | `flutter.main7dL5&gK9q@2mF` and completion suffix | `[String]` if it was mutated |

User-entered list names are used directly as preference keys. There are no stable list identifiers, schema version, transaction boundary, or migration marker.

### 3.4 Confirmed defects and data risks

The native rewrite must not reproduce these behaviors:

1. **First-launch crash path:** when the master list key is absent, code can force-unwrap a missing entry from `checklistMap`.
2. **Tutorial list becomes unreachable:** the drawer lists only user-created lists. After switching away, there is no working row to select the tutorial list again.
3. **Tutorial changes do not restore:** changes can be written under the special key, but loading reconstructs hard-coded tutorial content.
4. **Non-unique item IDs:** new item IDs use `currentCount + 1`; deleting and adding can reuse an existing ID, breaking dismissible row identity and deterministic ordering.
5. **Parallel arrays can diverge:** text and completion arrays are separate, and reconstruction indexes the completion array without checking its length.
6. **Unawaited writes can race:** persistence futures are not awaited. Adding an item briefly writes an empty completion array before a later sort writes the intended array.
7. **Incomplete deletion:** deleting a list removes the text key but leaves its completion key and stale in-memory map entry.
8. **Key collision risk:** because list names become keys, a name ending in `_completion` can collide semantically with another list's completion storage.
9. **Incorrect initial preference write:** one branch stores the selected-list value using the sentinel name as the key instead of writing `lastLoadedList`.
10. **No storage failure handling:** persistence failures are ignored and the UI always behaves as if saving succeeded.
11. **Template test is invalid:** the only Flutter test looks for a counter that does not exist.
12. **Unmanaged controller:** the item text controller is not disposed.
13. **Fixed light colors:** hard-coded white, black, teal, and grey values do not provide a considered dark-mode or increased-contrast result.
14. **Excess confirmation friction:** every item deletion requires an alert even though it is a routine, recoverable action.
15. **Mixed responsibilities:** a single stateful page owns view composition, selection, sorting, validation, persistence, and destructive workflows.

### 3.5 Existing assets and identity

- Preserve the App Store bundle identifier `com.jianyang.simpleChecklist` so the native binary installs as an update and retains the existing application container.
- Preserve the existing signing team unless App Store Connect requires a correction.
- Preserve the display name “Simplistic Checklist” for the first native release unless a separate naming decision is made.
- Carry the existing 1024×1024 icon into the native asset catalog initially. Its visual treatment should be reviewed by the user in Xcode and on device.
- Remove the quote from the primary checklist workflow. The quote can appear once in a lightweight About surface so it does not consume daily working space.

## 4. Scope for the first native release

### 4.1 Release-critical features

#### Checklist management

- Always maintain at least one checklist.
- Create a checklist with a trimmed, non-empty name.
- Switch between checklists.
- Rename any checklist.
- Reorder checklists in explicit edit mode.
- Delete a checklist after confirmation when more than one exists.
- Persist the most recently selected checklist by stable UUID, not name.
- Show the remaining-item count in the list selector without turning it into a dashboard.

List names do not need to be database keys. UUID identity makes duplicate names technically safe. For user clarity, the first implementation should reject duplicates using a trimmed, case-insensitive comparison and show inline validation rather than a second error dialog. This rule can be relaxed later without a schema change.

#### Item management

- Add an item inline from the checklist screen.
- Trim leading and trailing whitespace and ignore empty submissions.
- Complete or uncomplete an item using a dedicated checkbox-style button.
- Keep incomplete items above completed items.
- Preserve deterministic manual order within each completion group.
- Edit item text inline.
- Reorder items within their current completion group in edit mode.
- Delete an item with a standard swipe action or context-menu action.
- Clear completed items after confirmation.
- Mark all items incomplete using the current “reset” behavior, with undo rather than a blocking confirmation.
- Show or hide completed items from the checklist menu.

#### Reliability and recovery

- Save every mutation through one tested persistence boundary.
- Surface save failures and revert the failed in-memory mutation when possible.
- Support undo for item delete, item completion changes, item edits, reorders, and “mark all incomplete.”
- Confirm deleting a whole checklist and clearing all completed items.
- Never silently replace or reset a store that fails to open.
- Restore a valid list selection after launch; fall back to the first list only if the prior UUID is no longer present.

#### Existing-user migration

- Import every recoverable user-created list and item from Flutter preferences exactly once.
- Preserve list order, item text, item completion, and last-selected list when valid.
- Recover custom items added to the legacy tutorial list without re-seeding the obsolete tutorial instructions.
- Tolerate missing, malformed, mismatched, orphaned, and colliding legacy preference values without crashing.
- Do not remove old Flutter preference keys in the first native release.

### 4.2 Small improvements approved by the product principle

These features improve common actions without adding a second task-management system:

- Inline item entry instead of an add-item modal.
- Paste several lines through “Add Multiple Items,” creating one item per
  non-empty line in one undoable command.
- Inline editing instead of a detail screen.
- Manual reordering.
- Move an item to another checklist from its context menu.
- Duplicate a checklist as a reusable personal template.
- Clear completed.
- Show/hide completed.
- Remember completed-item visibility independently for each checklist.
- Undo.
- Remaining-item counts.
- Keyboard submit and common iPad keyboard shortcuts.
- Share a checklist as portable plain text through the system share sheet.

### 4.3 Explicit non-goals

The following are intentionally excluded from the first native release:

- Due dates, times, notifications, alarms, and calendar integration.
- Recurring tasks.
- Subtasks or nested checklists.
- Notes, URLs, file attachments, photos, and scanning.
- Priority levels, tags, flags, smart lists, filters, and saved searches.
- Natural-language parsing.
- Accounts, collaboration, shared lists, and activity history.
- iCloud or CloudKit sync.
- Widgets, Live Activities, App Intents, Siri, and Shortcuts.
- Apple Watch, macOS, visionOS, or Android clients.
- Themes, per-list icons, and arbitrary list colors.
- Analytics, advertising, subscriptions, or third-party SDKs.
- A permanent onboarding checklist.
- A settings screen that exists only to hold optional preferences.

These are not rejected forever. They require evidence that they support the app's simplicity rather than weaken it.

## 5. Information architecture and interaction design

### 5.1 Root navigation

Use a two-column `NavigationSplitView`:

- Sidebar: checklists and list management.
- Detail: the selected checklist.

On iPad and wide layouts, both columns can remain visible. In compact iPhone layouts, the split view collapses to standard stack navigation. On launch, the app should restore the last-used list and show its detail; the system back/sidebar control reveals all lists.

This replaces the custom drawer with a standard, adaptive pattern and gives the selected list a real navigation title.

### 5.2 Lists sidebar

Contents:

- Large navigation title: “Lists.”
- One row per list with name and subtle remaining count.
- A standard toolbar add button for “New List.”
- An Edit action for reordering and deleting lists.
- Context-menu actions for Rename and Delete.
- A secondary menu containing About.

Behavior:

- Creating or selecting a list moves focus to its detail in compact layouts.
- The selected list remains visually selected in regular layouts.
- New-list and rename prompts validate in place.
- Delete is unavailable for the sole remaining list; the user can rename it and clear its content instead.

### 5.3 Checklist detail

Contents, in reading order:

1. Navigation title containing the checklist name.
2. Optional compact progress summary such as “3 remaining,” using secondary text.
3. Incomplete items section.
4. Completed items section when enabled and non-empty.
5. Persistent inline composer at the bottom.

Toolbar/menu actions:

- Rename List.
- Edit Order when at least one completion group has multiple items.
- Show or Hide Completed when completed items exist.
- Mark All Incomplete when completed items exist.
- Clear Completed… when completed items exist.
- Delete List… when more than one list exists.
- Undo/Redo when available, exposed through standard system commands and the menu rather than permanent toolbar clutter.

The list should use native `List` and `Section` behavior. Avoid wrapping every row in a custom floating card; this lets separators, selection, swipe actions, materials, and accessibility adapt with the system.

### 5.4 Inline item composer

- A single-line or vertically expanding `TextField` labeled “New item.”
- A visible Add button that is disabled for whitespace-only input.
- Return submits the item and keeps focus so multiple items can be entered quickly.
- Command-N opens the new-list prompt when a hardware keyboard is available.
- The composer remains the one primary add action even when the list is empty;
  the empty state explains what to do but does not add a competing button.
  Focus is intentionally user-controlled so VoiceOver, hardware keyboards, and
  list selection are not interrupted by an automatic focus jump.
- On iOS 26, use the standard safe-area bar API where it provides the correct system functional layer. On iOS 17–18, use a restrained safe-area inset with system material. Do not manually imitate Liquid Glass.

### 5.5 Checklist row

- Leading completion button with a minimum 44×44-point hit target.
- Item title as the dominant label, supporting multiple lines and Dynamic Type.
- Completed styling uses both a changed symbol/state announcement and subdued text; color and strikethrough are not the only indicators.
- Tapping the completion control toggles state.
- Tapping the title starts inline editing.
- Trailing swipe action deletes.
- Context menu offers Edit and Delete, matching the swipe action.
- VoiceOver custom actions provide Complete/Uncomplete, Edit, Move, and Delete alternatives.
- Completion can use subtle selection feedback and a short transition, disabled or simplified under Reduce Motion.

### 5.6 Ordering rules

Each list and item has a persisted integer `sortOrder`.

- Lists display by `sortOrder`.
- Items display in two groups: incomplete, then complete.
- Within each group, items display by `sortOrder`, with creation date and UUID as deterministic tie-breakers.
- Completing an item moves it to the completed group but retains its relative order value.
- Uncompleting returns it to the corresponding position among incomplete items.
- Reordering changes only the items in the visible group, then normalizes integer order values for the whole list.
- When completed items are hidden, they are not included in move calculations.

This preserves the current “completed at the bottom” behavior while adding predictable reordering.

### 5.7 Empty, loading, and error states

#### New/empty list

Use `ContentUnavailableView` with:

- Title: “No items yet.”
- Description: “Add the first item to start this checklist.”
- Action: focus the inline composer.

Do not seed tutorial items into user data.

#### Migration/loading

- Show a simple progress indicator only while opening the data store and running the one-time import.
- Do not show a multi-step onboarding screen.

#### Persistence failure

- If the model container cannot open, show a blocking recovery view with a concise explanation and Retry.
- Never silently fall back to an in-memory store or delete the on-disk database.
- If a mutation cannot save, show an alert and restore the last durable state where possible.
- Use structured logging for developer diagnosis without logging task text.

### 5.8 What is removed or demoted

- Remove the permanent quote header from the daily checklist screen.
- Replace the tutorial checklist with an actionable empty state.
- Replace the custom drawer with adaptive native navigation.
- Replace add-item alerts with the inline composer.
- Remove confirmation for each individual item deletion; make the action undoable.
- Move reset, clear, rename, and delete-list actions out of the primary toolbar into a clear secondary menu.
- Remove custom rounded card styling around standard rows.
- Remove fixed light-mode background and text colors.

## 6. Native technical architecture

### 6.1 Platform and toolchain

- Xcode: current installed Xcode 26.6.
- SDK: current installed iOS SDK.
- Deployment target: iOS 17.0.
- Language: Swift 6 language mode with complete concurrency checking.
- UI: SwiftUI.
- Persistence: SwiftData, local store only.
- Unit/integration tests: Swift Testing.
- UI tests: XCTest/XCUITest.
- Dependencies: Apple frameworks only; no CocoaPods or Swift packages.
- Devices: iPhone and iPad, all orientations supported where layouts remain useful.

The iOS 17 floor is intentional: it permits SwiftData, `NavigationSplitView`, `ContentUnavailableView`, modern observation, and current SwiftUI patterns without maintaining a second legacy architecture.

### 6.2 Project conversion

Create a fresh native project rather than incrementally stripping Flutter build phases from `Runner.xcodeproj`.

Proposed shipped layout:

```text
ios/
  SimplisticChecklist.xcodeproj/
  SimplisticChecklist/
    App/
      SimplisticChecklistApp.swift
      AppRootView.swift
      AppLaunchState.swift
    Models/
      Checklist.swift
      ChecklistItem.swift
      ChecklistSchema.swift
    Persistence/
      ModelContainerFactory.swift
      ChecklistMutationService.swift
    Migration/
      LegacyPreferenceKeys.swift
      LegacyChecklistParser.swift
      LegacyChecklistMigrator.swift
    Features/
      Lists/
        ListsSidebarView.swift
        ListRowView.swift
        ListNamePrompt.swift
      Checklist/
        ChecklistDetailView.swift
        ChecklistItemRow.swift
        ItemComposerView.swift
        ChecklistEmptyView.swift
    Shared/
      Validation/
        ChecklistInputValidator.swift
      Ordering/
        ChecklistOrderer.swift
      About/
        AboutView.swift
    Resources/
      Assets.xcassets/
      Localizable.xcstrings
      PrivacyInfo.xcprivacy
  SimplisticChecklistTests/
  SimplisticChecklistUITests/
```

The exact folder names can evolve, but files must stay focused. Views should not own migration, storage parsing, or cross-feature business rules.

### 6.3 Legacy archive

During the project-conversion phase, move the old implementation under:

```text
Legacy/FlutterApp/
```

The archive should include the old Dart source, Flutter manifest and lockfile, old generated platform projects, tests, and original Flutter assets. Add a short `Legacy/FlutterApp/README.md` stating:

- The archived revision and date.
- That it is not part of the native build.
- The legacy storage keys the native migrator reads.
- That downgrade from the native app to Flutter is unsupported.

The native project must not reference, compile, embed, or package anything from `Legacy/FlutterApp`. After at least one stable native release and successful migration monitoring, the archive can be removed in a separate decision; Git history remains the permanent record.

### 6.4 Data models

#### `Checklist`

```text
id: UUID                 unique, stable identity
name: String             validated display name
sortOrder: Int           explicit sidebar order
createdAt: Date
updatedAt: Date
items: [ChecklistItem]   cascade delete relationship
```

#### `ChecklistItem`

```text
id: UUID                 unique, stable row identity
title: String            validated item text
isCompleted: Bool
sortOrder: Int           deterministic order within list
createdAt: Date
updatedAt: Date
checklist: Checklist?    inverse relationship
```

Use a versioned SwiftData schema from the first native release so later native schema changes have an explicit `SchemaMigrationPlan`. Use unique constraints for UUIDs. The store is local-only; do not shape the first schema around hypothetical CloudKit limitations.

### 6.5 State ownership

- `ModelContainerFactory` creates the persistent container and an in-memory container for tests/previews.
- `AppLaunchState` owns store-open and one-time-migration state.
- SwiftData queries provide read state to the sidebar and selected checklist.
- `ChecklistMutationService`, isolated to the main actor, is the single boundary for validated model mutations and explicit saves. Every public mutation is one named command with exactly one save on success; failed saves roll back without entering history. Reversible changes are stored as service-owned before/after snapshots because SwiftData's implicit undo groups cannot provide deterministic command boundaries around explicit saves.
- The root view stores the selected checklist UUID using `AppStorage` (the
  standard store in production and an isolated suite for UI-test launches); it
  resolves that UUID against actual models before presenting detail.
- Views own only ephemeral UI state such as draft text, focus, prompt visibility, edit mode, and completed-item visibility.
- Keep undo and redo in the mutation service rather than binding them to SwiftData's
  implicit `UndoManager` groups. The service exposes the same menu/system-facing
  actions while retaining exact, retryable save semantics.

A generic repository abstraction is not needed for this local-only app. A focused mutation service and in-memory SwiftData tests give sufficient separation without adding speculative layers.

### 6.6 Validation rules

- Trim leading/trailing whitespace and newlines before creating or committing an edit.
- Item title: 1–500 characters after trimming.
- List name: 1–80 characters after trimming.
- Reject case-insensitive duplicate list names in the native UI.
- Editing an existing item to empty does not silently delete it; the edit is rejected and the original value remains.
- Migration preserves legacy text even when it exceeds new limits; validation applies to subsequent user edits.
- Never put user-entered text in logs or crash diagnostics.

### 6.7 Concurrency and saving

The data set is small and all user mutations originate in the UI, so use the main SwiftData context under `@MainActor`.

For every command:

1. Validate input.
2. Capture the pre-mutation snapshot and apply the mutation.
3. Explicitly save the model context exactly once.
4. Append the before/after snapshot pair to history only after the save succeeds.
5. On error, roll back or restore the prior snapshot, leave undo/redo unchanged, and surface a user-readable error.

Do not add background actors, synchronization engines, or custom queues until measured need exists.

## 7. Existing-user data migration

### 7.1 Migration guarantees

The App Store update must preserve existing lists and tasks. This requires all of the following:

- Keep `com.jianyang.simpleChecklist` unchanged.
- Keep the same App Store record and signing identity.
- Run migration before seeding a new empty checklist.
- Treat every legacy value as untrusted input.
- Make import idempotent and transaction-like.
- Mark migration complete only after SwiftData saves successfully.
- Leave legacy preference keys untouched in the first native release.

The native app does not need to write changes back into Flutter's format. A downgrade to the Flutter binary after native use is unsupported and would not contain native changes.

### 7.2 Migration pipeline

Split migration into a pure parser and a persistence writer:

1. `LegacyChecklistParser` receives a dictionary-like preference reader and returns an immutable import plan plus non-sensitive warnings.
2. `LegacyChecklistMigrator` inserts the import plan into an empty SwiftData context, saves, and records a migration receipt.

This separation makes corrupt legacy data testable without relying on a simulator's actual preferences.

### 7.3 Import algorithm

1. Open the SwiftData container.
2. Check for a native migration receipt or any existing native checklist.
3. If native data exists, do not duplicate it. Resolve selection and continue.
4. Read `flutter.masterChecklist7dL5&gK9q@2mF` as an array of names. If absent or malformed, treat it as empty.
5. For each master-list entry, in stored order:
   - Require a non-empty string name for display.
   - Read `flutter.<name>` as an item-text array.
   - Read `flutter.<name>_completion` as an optional completion array.
   - For every item text, create a new UUID.
   - Parse the completion at the same index when it is exactly `true` or `false`, case-insensitively; otherwise default to incomplete.
   - Ignore completion entries beyond the number of item texts.
   - Preserve duplicate item text and original item order.
6. Read the special tutorial-list item arrays if present.
   - Compare each text to the seven known tutorial messages from `ChecklistItem.defaultChecklist()`.
   - Exclude known tutorial messages from native user data.
   - Import any other text as user-created items into a list named “Checklist,” preserving aligned completion values.
7. Ignore orphan preference keys that are not referenced by the master list, except the special tutorial key. This prevents deleted lists and suffix collisions from reappearing as ghost lists.
8. Resolve `flutter.lastLoadedList`:
   - Map a valid imported list name to its new UUID.
   - Map the special tutorial sentinel to the recovered “Checklist” list if it exists.
   - Otherwise select the first imported list.
9. If no recoverable user data exists, create one empty checklist named “Checklist.”
10. Normalize list and item order to sequential integers.
11. Insert all models and a migration receipt in one model-context save.
12. After save succeeds, persist the selected UUID and mark launch migration complete.
13. If save fails, do not write the completion marker. Show a retryable error and retry on the next launch.

### 7.4 Collision and corruption handling

- The legacy app allowed names to become raw keys. The parser should use the master list as the authority and validate that an item array looks like task text while a completion array contains Boolean strings.
- If two legacy names normalize to the same native case-insensitive name, preserve both by appending a localized numeric suffix such as “Work 2.”
- If a name is only whitespace, use “Untitled List” with a numeric suffix.
- If an item value is not a string, skip that item and record only a count in diagnostics.
- If the completion array is shorter, default missing values to incomplete.
- If the completion array is longer, ignore extra values.
- If `lastLoadedList` references a missing or corrupt list, select the first successfully imported list.
- Never crash, delete the old values, or silently reset the SwiftData store in response to corrupt legacy preferences.

### 7.5 Migration verification fixture set

Before implementation, capture preference dictionaries for:

- No legacy keys.
- One empty custom list.
- Multiple lists with mixed completion.
- A valid last-selected custom list.
- Missing `lastLoadedList`.
- Missing item array.
- Missing completion array.
- Short and long completion arrays.
- Invalid Boolean strings.
- Empty and whitespace list names.
- Names differing only by case.
- A list whose name ends in `_completion`.
- Deleted-list orphan keys.
- Tutorial-only data.
- Tutorial data plus custom items.
- A partially written add-item state with an empty completion array.
- A migration retry after a simulated save failure.
- A second launch after successful import, proving no duplicates.
- Unprefixed keys that resemble Flutter keys, proving unrelated defaults are
  ignored.

### 7.6 Upgrade acceptance test

Before release, the user should perform an install-over test on a simulator or device:

1. Install the last Flutter build using the production bundle identifier.
2. Create multiple lists with duplicate item text and mixed completion.
3. Add custom items to the tutorial list.
4. Select a non-first list and terminate the app.
5. Install the native build as an update without deleting the app.
6. Confirm all recoverable content, order, completion, and selection.
7. Edit native data, relaunch, and confirm native persistence.
8. Confirm old preference keys remain present for recovery but are no longer mutated.

## 8. Accessibility, localization, and privacy

### 8.1 Accessibility requirements

- Minimum 44×44-point primary touch targets.
- Dynamic Type through all accessibility sizes without clipped titles or hidden actions.
- VoiceOver labels such as “Mark Buy milk complete” and values such as “Completed.”
- VoiceOver custom actions for gesture-only operations.
- Delete and edit must be available without requiring a swipe.
- Completion must not be conveyed by color alone.
- Logical focus order: navigation, list status, items, composer.
- Support Bold Text, Button Shapes, Increased Contrast, Reduce Transparency, and Reduce Motion.
- Avoid automatic time-limited undo banners; undo remains available through the system and menu until the next logical command boundary.
- Support hardware-keyboard navigation and Return-to-add on iPad.
- Verify right-to-left layout even though English is the only launch language.

### 8.2 Localization readiness

- Store visible strings in `Localizable.xcstrings` from the start.
- Use localized pluralization for remaining and completed counts.
- Avoid string concatenation for sentences.
- Keep user-created names and task text unchanged.
- English ships first; localization readiness must not add a settings interface.

### 8.3 Privacy

- No network entitlement or requests.
- No analytics, ads, crash-reporting SDK, account, or tracking.
- Checklist contents remain in the application container.
- Include `PrivacyInfo.xcprivacy`.
- Declare no collected data and no tracking.
- Declare the approved app-only `UserDefaults` required-reason code for legacy migration and selected-list preference.
- Generate and review Xcode's privacy report before release.

## 9. Test-driven implementation strategy

Per repository policy, tests are written before the production behavior they specify. The coding agent will not run an iOS build or `xcodebuild`; the user will build and run tests in Xcode at the named gates.

### 9.1 Unit tests with Swift Testing

#### Validation

- Trims valid item and list input.
- Rejects empty and whitespace-only input.
- Enforces native edit limits without truncating silently.
- Detects duplicate list names case-insensitively.

#### Ordering

- Incomplete items precede completed items.
- Relative order is stable within both groups.
- Toggle retains the persisted order value.
- Reordering one group does not reorder the other.
- Normalization removes gaps and ties deterministically.

#### Mutations

- Add, edit, toggle, delete, clear completed, and mark all incomplete.
- Create, rename, reorder, and delete list.
- Cannot delete the last list.
- Cascade deleting a list deletes its items.
- Each mutation updates `updatedAt` and saves once.
- Failed saves restore or report the intended state.
- Undo restores the exact prior values and order.

#### Migration parser

- Every fixture in Section 7.5.
- Parser output never uses legacy names as identity.
- Diagnostics never contain user task text.

### 9.2 SwiftData integration tests

Use an in-memory `ModelContainer` to verify:

- Schema creation.
- Unique UUID behavior.
- Relationships and cascade deletion.
- Persisted ordering queries.
- Explicit save and refetch.
- Migration import and idempotency.
- Selection fallback after deleting the selected list.

Add one on-disk temporary-store test to prove persistence across container recreation. Use a single task-specific temporary location and clean it recoverably after the suite.

### 9.3 XCUITest flows

- Launch tests with explicit, deterministic arguments: fresh in-memory for
  isolated workflows, a named persistent UI-test store for relaunch checks,
  and an in-memory seeded legacy fixture for the migration path. The
  persistent mode supports an explicit reset argument; no test silently
  deletes a production store.
- Fresh launch shows one empty list and one visible composer; the test enters
  the first item explicitly rather than relying on automatic focus.
- Add several items rapidly with Return.
- Complete and uncomplete an item.
- Edit item text.
- Delete and undo an item.
- Reorder items.
- Create, switch, rename, reorder, and delete lists.
- Hide and show completed items.
- Clear completed after confirmation.
- Relaunch restores the selected list and content.
- Migration test launch from a seeded legacy preference fixture.

Use accessibility identifiers only where stable semantic labels cannot uniquely locate an element.

### 9.4 Manual visual and accessibility matrix

The user will perform visual verification, as requested:

- Current iPhone simulator on iOS 26.
- A compact-width iPhone layout.
- iPad portrait, landscape, split view, and resized windows.
- Light mode, dark mode, and increased contrast.
- Default and largest accessibility Dynamic Type.
- VoiceOver reading order and custom actions.
- Reduce Motion and Reduce Transparency.
- Long list names, long item text, empty lists, and large lists.
- Keyboard creation, edit, escape/cancel, and navigation.
- Migration upgrade on a device or simulator without uninstalling.

## 10. Phased implementation plan

### Phase 0: Freeze the contract and fixtures

1. Confirm the assumptions in Section 12.
2. Record the seven tutorial strings and exact legacy key names in migration fixtures.
3. Add the corrupt/mismatched legacy fixture matrix.
4. Capture the current icon and quote assets.
5. Document the current App Store version/build number from App Store Connect; the repository values are inconsistent.

Exit criteria:

- The data migration inputs and release identity are unambiguous.
- No production code has changed.

### Phase 1: Archive Flutter and create the native shell

1. Move the old application to `Legacy/FlutterApp` with its archive README.
2. Create `SimplisticChecklist.xcodeproj` and native source/test targets.
3. Preserve bundle identifier, signing team, display name, orientations, and app icon.
4. Remove Flutter build phases, bridge headers, generated registrants, CocoaPods, and workspaces from the shipped project.
5. Configure iOS 17, Swift 6, warnings, strict concurrency, and current SDK.
6. Add localization catalog and privacy manifest.

Test-first work:

- App-container creation test.
- Empty in-memory schema test.

User build gate:

- Open the fresh project and run the empty native shell and tests on an explicit iOS simulator.

### Phase 2: Persistence schema and legacy migration

1. Write migration parser tests and fixtures.
2. Define versioned SwiftData models.
3. Implement parser, migrator, migration receipt, and container launch state.
4. Implement retryable store/migration error UI.
5. Import legacy data before default-list seeding.

User build gate:

- Run all unit/integration tests.
- Perform the install-over migration acceptance test before UI feature work depends on the new store.

### Phase 3: Core checklist workflow

1. Write mutation and ordering tests.
2. Implement checklist detail, native rows, inline composer, completion grouping, and empty state.
3. Implement edit, reorder, delete, undo, clear completed, mark all incomplete, and show/hide completed.
4. Add save-error recovery.

User build gate:

- Exercise the entire single-list workflow on iPhone in light and dark mode.
- Run unit and UI tests.

### Phase 4: Multiple-list workflow

1. Write list creation, validation, selection, rename, ordering, and deletion tests.
2. Implement `NavigationSplitView` sidebar and compact navigation.
3. Restore stable UUID selection.
4. Add remaining counts and About surface.

User build gate:

- Verify iPhone compact navigation and iPad split-view behavior.
- Run all tests without rebuilding when only tests are rerun and the compiled code is unchanged.

### Phase 5: Accessibility and modern-design polish

1. Add semantic accessibility labels, values, actions, focus behavior, and identifiers.
2. Verify Dynamic Type layout and semantic colors.
3. Add restrained animation and sensory feedback with accessibility fallbacks.
4. Review system materials, safe-area behavior, toolbars, menus, and control crowding on iOS 26.
5. Remove any custom styling that fights the platform hierarchy.
6. Optionally add plain-text Share only if it does not delay stabilization.

User build gate:

- Complete the manual matrix in Section 9.4.

### Phase 6: Release hardening

1. Run the complete test plan.
2. Repeat fresh-install and upgrade-install testing.
3. Verify no Flutter, CocoaPods, or third-party frameworks are present in the archive.
4. Generate the privacy report.
5. Validate icons, launch screen, version/build, signing, and archive settings.
6. Update the root README with native development and migration notes.
7. Search for debug logs, force unwraps, placeholder strings, TODOs, and legacy runtime references.
8. Archive in Xcode and perform TestFlight migration testing with a real prior-user dataset.

Exit criteria:

- Definition of Done in Section 11 is satisfied.

## 11. Definition of Done

### Product

- A first-time user understands the screen and can add an item within seconds.
- Existing users retain all recoverable lists, task text, completion, order, and selection.
- All current meaningful features have a native equivalent.
- Edit, reorder, rename, clear completed, and undo work consistently.
- No non-goal feature has leaked into the interface.

### Design

- There is one obvious primary action on the checklist screen.
- The daily workflow contains no tutorial content or permanent quote header.
- Navigation, toolbars, menus, sheets, alerts, lists, and controls use native patterns.
- iOS 26 appearance is adopted through system components, not imitation.
- iPhone and iPad layouts are coherent at all supported sizes.
- Dark mode and accessibility settings remain legible and operable.

### Engineering

- Native Swift/SwiftUI/SwiftData code only in the shipped target.
- No third-party dependencies.
- Swift 6 concurrency warnings are addressed, not suppressed globally.
- Every persisted entity has stable UUID identity and deterministic order.
- Every mutation goes through a tested save boundary.
- Migration is defensive, idempotent, and leaves legacy data intact.
- No force unwraps on persisted or migrated data paths.
- Tests cover the domain, store, migration, and primary UI flows.
- Source files remain small and single-purpose.

### Release

- Bundle identifier and App Store record are unchanged.
- Production version/build numbers are valid and greater than the live release.
- Fresh install and install-over migration both pass.
- Privacy manifest and generated privacy report match the local-only product behavior.
- User has completed visual checks and an Xcode build/archive.

## 12. Implementation assumptions and decision log

These are the current recommended defaults. Change them before implementation if product intent differs.

| Decision | Recommendation | Reason |
| --- | --- | --- |
| Platforms | iPhone and iPad only | Keeps the rewrite focused and matches the App Store update path. |
| Minimum OS | iOS 17 | Enables a coherent modern SwiftUI/SwiftData architecture. |
| Storage | Local SwiftData | Reliable and private without accounts or sync complexity. |
| Existing data | One-time import, old keys retained | Prevents data loss while avoiding a permanent compatibility layer. |
| Flutter code | Archive in repo, exclude from native target | Keeps historical implementation available during rollout. |
| First-run content | One empty list named “Checklist” | Empty-state guidance is cleaner than tutorial tasks. |
| Multiple lists | Keep and improve | It is already a core shipped capability. |
| Default list deletion | Require at least one list | Avoids a special undeletable tutorial list while preserving a valid app state. |
| Quote | Move to About | Preserves identity without obstructing the working surface. |
| Dependencies | None | The feature set is fully supported by Apple frameworks. |
| Cloud sync | Deferred | Valuable but materially expands schema, conflict, entitlement, and support scope. |
| Share as text | Optional after core stabilization | Useful and low-cost, but not essential to the checklist promise. |
| App name/icon | Preserve initially | Avoids mixing product rebranding with a high-risk data migration. |

## 13. Main risks and mitigations

| Risk | Impact | Mitigation |
| --- | --- | --- |
| App update uses a different bundle ID | Existing app container and preferences are inaccessible | Lock the production identifier before project creation and verify the archive. |
| Legacy arrays are corrupt or mismatched | Crash or task loss during upgrade | Pure defensive parser, fixture matrix, defaults for missing completion, never force-index. |
| Migration repeats after interruption | Duplicate lists/tasks | Check native data/receipt, save import atomically, mark complete only after success. |
| New default data is created before import | Existing data appears overwritten or hidden | Migration is a launch prerequisite; seed only after parser reports no recoverable data. |
| SwiftData store cannot open | Potential data loss if reset automatically | Show recovery UI; never silently erase or use in-memory fallback in production. |
| Manual reorder conflicts with completion grouping | Items appear unpredictably | Persist one order value and define stable grouping semantics in tests. |
| Native design becomes overly custom | Future OS updates look dated or broken | Prefer system components and semantic styling; minimize custom functional-layer effects. |
| “Minor” features accumulate | App becomes another complex task manager | Enforce non-goals and require a workflow benefit for any scope addition. |
| Flutter archive accidentally ships | Larger binary or build dependency returns | Place it outside native target, inspect build phases, and audit final archive contents. |
| Agent cannot run iOS builds | Compile errors discovered later | Use small phases and explicit user Xcode build/test gates after each meaningful layer. |

## 14. Primary Apple references

- [Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/)
- [Design principles](https://developer.apple.com/design/human-interface-guidelines/design-principles)
- [Adopting Liquid Glass](https://developer.apple.com/documentation/TechnologyOverviews/adopting-liquid-glass)
- [NavigationSplitView](https://developer.apple.com/documentation/swiftui/navigationsplitview)
- [ContentUnavailableView](https://developer.apple.com/documentation/swiftui/contentunavailableview)
- [Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility)
- [Undo and redo](https://developer.apple.com/design/human-interface-guidelines/undo-and-redo)
- [ModelContainer](https://developer.apple.com/documentation/swiftdata/modelcontainer)
- [Preserving model data across launches](https://developer.apple.com/documentation/swiftdata/preserving-your-apps-model-data-across-launches)
- [Swift Testing](https://developer.apple.com/documentation/testing)
- [Privacy manifest files](https://developer.apple.com/documentation/bundleresources/privacy-manifest-files)

Legacy-format reference:

- [Flutter shared_preferences migration and prefixes](https://github.com/flutter/packages/blob/main/packages/shared_preferences/shared_preferences/README.md)
