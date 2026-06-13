# CLAUDE.md

This file provides guidance to Claude Code when working with code in this repository.

## Build & Test Commands

```bash
# Build for simulator
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  /Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild \
  build -scheme Focal -destination 'platform=iOS Simulator,name=iPhone 17'

# Run all tests
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  /Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild \
  test -scheme Focal -destination 'platform=iOS Simulator,name=iPhone 17'

# Run a single unit test
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  /Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild \
  test -scheme Focal -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:FocalTests/TaskStoreTests/testMethodName
```

## Code Style

- **Zero code comments** — no comments in any Swift file, ever. Remove any you encounter.
- The FocalUITests target exists but contains only auto-generated stubs; no UI tests to maintain.

## Architecture

Focal is an iOS 26 SwiftUI app that shows one task at a time to reduce ADHD decision paralysis. It uses **SwiftData** for persistence and the `@Observable` macro (not `ObservableObject`) for state management.

### Data layer

- `FocalTask.swift` — `@Model` type. Also holds `note`, `dueDate`, `estimatedMinutes`, `recurrence`, and a cascade-delete `subtasks` relationship. `TaskLimit` enum (titleMax: 80, noteMax: 300) and the `RecurrenceRule` enum (daily/weekdays/weekly/monthly, with `nextDate(from:)` and `nextDate(from:notBefore:)`) live here.
- `SubTask.swift` — `@Model` type for a task's checklist items (`title`, `isCompleted`, `createdAt`, inverse `task` relationship).

### State layer

- `TaskStore.swift` — `@Observable` class. Owns the session queue: a randomised, non-repeating cycle of incomplete tasks (due-today/overdue tasks are seeded first). Key methods: `done()`, `notNow()`, `addTask(title:note:dueDate:estimatedMinutes:recurrence:subtaskTitles:)`, `deleteTask(_:)` / `undoDelete()` (5s window, extended to 10s under VoiceOver/Switch Control), `prioritizeTask(_:)` ("Focus now"), `restoreTask(_:)`, `toggleSubtask(_:in:)`, and `completeIfAllSubtasksDone(_:)`. Completing a recurring task spawns its next occurrence. `advance(with:)` accepts a pre-fetched list to avoid redundant DB round-trips. `pendingUndo` backs the undo banner.
- `NotificationManager.swift` — singleton for inactivity notification scheduling. `NotificationManager.Key` is the single source of truth for all `UserDefaults`/`AppStorage` key strings and color scheme value constants.

### UI layer

- `FocalApp.swift` — creates `ModelContainer` and `TaskStore` in `init()`, injects both into the environment. Owns `preferredColorScheme` from `@AppStorage`.
- `MainView.swift` — root view. Shows the current task card (title, note, subtask checklist, and estimate/due/recurrence meta badges) with Done / Not now buttons; animates task transitions (respects Reduce Motion and the in-app toggle). Hosts the undo banner. Done / Not now stack vertically at accessibility Dynamic Type sizes.
- `QuickAddSheet.swift` — sheet for adding a new task. A "More options" disclosure exposes due date, estimate, recurrence; a Subtasks section adds checklist items.
- `EditTaskSheet.swift` — sheet for editing or deleting an existing task, including its scheduling fields and subtasks; saves via `@Environment(\.modelContext)`, deletes via `store.deleteTask(_:)`. Guards unsaved changes with a discard confirmation.
- `AllTasksView.swift` — sheet listing all incomplete and completed tasks. Incomplete rows: tap to edit, long-press context menu for "Focus Now" / "Edit", swipe-right for "Focus now", swipe-left to delete. Completed rows: swipe-right to restore, swipe-left to delete. Opens Settings via gear icon.
- `SettingsView.swift` — notifications (inactivity threshold), color scheme, animations toggle.
- `LimitedTextField.swift` — reusable `TextField` with live character counter (shown in last 20 chars, red at limit) and hard clamp via `onChange`.

### Extensions

- `Extensions.swift` — `String.nilIfEmpty: String?` (empty string → nil) and `String.trimmed: String` (strips leading/trailing whitespace only — does not coerce to nil). Also holds shared formatting helpers (`formatEstimateMinutes`, `formatDueDate` → `DueDateDisplay`) and reusable views: `EstimatePicker`, `RecurrencePicker`, `SubtaskInputField`, and `UndoBanner` (posts a VoiceOver announcement on appear).

### Testing

- **Unit tests** (`FocalTests/`) use **Swift Testing** (`import Testing`, `@Test`, `#expect`). All tests live in `TaskStoreTests`.
- To run a single test: `-only-testing:FocalTests/TaskStoreTests/methodName`

## Localisation

The app is localised into **English, Afrikaans (af), and Spanish (es)** using a single `Focal/Localizable.xcstrings` file (Xcode String Catalog format).

- All user-facing strings — including UI labels, accessibility labels, and accessibility hints — must have entries in this file for all three languages.
- SwiftUI string literals (`Text("...")`, `.accessibilityLabel("...")`, etc.) are automatically resolved as `LocalizedStringKey` and will look up the catalog.
- String interpolation with `\(variable)` produces a plain `String` **not** a `LocalizedStringKey`. Use `Text("\(variable) key")` (the `Text` initialiser) or `String(localized:)` to keep interpolated strings localized.
- Plural rules (e.g. "%lld tasks", "%lld characters remaining") use the `variations.plural` structure in xcstrings with `one` and `other` forms for each language.
- When adding new strings, add the key and all three translations before committing. Run `xcodebuild` to catch missing keys early.

## Known platform quirks

- iOS 26 uses `.glassEffect()` (Liquid Glass) — requires the iOS 26 SDK; no fallback.
- iOS 27 ready while keeping the iOS 26 deployment target: the app already satisfies the iOS 27 SDK's mandatory scene-based lifecycle (SwiftUI `App` lifecycle + `UIApplicationSceneManifest_Generation`, no `AppDelegate`), never sets the deprecated `UIDesignRequiresCompatibility` Liquid Glass opt-out, and does no networking (so the stricter iOS 27 ATS/TLS 1.2+ enforcement does not apply).
- Inject `@Observable` stores with `.environment(store)`, access with `@Environment(TaskStore.self)`. Do not use `ObservableObject`/`@StateObject`.
- `PBXFileSystemSynchronizedRootGroup` in Xcode 26: files added or deleted from `Focal/` are auto-included without editing `.pbxproj`.
