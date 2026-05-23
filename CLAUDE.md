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

- `FocalTask.swift` — `@Model` type. `TaskLimit` enum lives here (titleMax: 80, noteMax: 300).

### State layer

- `TaskStore.swift` — `@Observable` class. Owns the session queue: a randomised, non-repeating cycle of incomplete tasks. Key methods: `done()`, `notNow()`, `addTask(title:note:)`, `deleteTask(_:)`. `advance(using:)` accepts a pre-fetched list to avoid redundant DB round-trips.
- `NotificationManager.swift` — singleton for inactivity notification scheduling. `NotificationManager.Key` is the single source of truth for all `UserDefaults`/`AppStorage` key strings and color scheme value constants.

### UI layer

- `FocalApp.swift` — creates `ModelContainer` and `TaskStore` in `init()`, injects both into the environment. Owns `preferredColorScheme` from `@AppStorage`.
- `MainView.swift` — root view. Shows the current task card with Done / Not now buttons; animates task transitions (respects Reduce Motion and the in-app toggle).
- `QuickAddSheet.swift` — sheet for adding a new task.
- `EditTaskSheet.swift` — sheet for editing or deleting an existing task; saves via `@Environment(\.modelContext)`, deletes via `store.deleteTask(_:)`.
- `AllTasksView.swift` — sheet listing all incomplete and completed tasks. Incomplete rows: tap to edit, long-press context menu for "Focus Now" / "Edit", swipe-right for "Focus now", swipe-left to delete. Completed rows: swipe-right to restore, swipe-left to delete. Opens Settings via gear icon.
- `SettingsView.swift` — notifications (inactivity threshold), color scheme, animations toggle.
- `LimitedTextField.swift` — reusable `TextField` with live character counter (shown in last 20 chars, red at limit) and hard clamp via `onChange`.

### Extensions

- `Extensions.swift` — `String.nilIfEmpty: String?` (empty string → nil). `String.trimmed: String` (strips leading/trailing whitespace only — does not coerce to nil).

### Testing

- **Unit tests** (`FocalTests/`) use **Swift Testing** (`import Testing`, `@Test`, `#expect`). All tests live in `TaskStoreTests`.
- To run a single test: `-only-testing:FocalTests/TaskStoreTests/methodName`

## Known platform quirks

- iOS 26 uses `.glassEffect()` (Liquid Glass) — requires the iOS 26 SDK; no fallback.
- Inject `@Observable` stores with `.environment(store)`, access with `@Environment(TaskStore.self)`. Do not use `ObservableObject`/`@StateObject`.
- `PBXFileSystemSynchronizedRootGroup` in Xcode 26: files added or deleted from `Focal/` are auto-included without editing `.pbxproj`.
