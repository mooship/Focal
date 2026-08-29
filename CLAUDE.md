# CLAUDE.md

Guidance for Claude Code (or any agent) working in this repository. Every claim
below is grounded in a specific file — check the cited path if you need more
detail than fits here.

## What this is

Focal (`Focal.xcodeproj`) is a native iOS/iPadOS SwiftUI app: one `@Model`
task type (`FocalTask`, plus a `SubTask` checklist-item model), one
`@Observable` state class (`TaskStore`), and a handful of SwiftUI views. No
backend, no networking, no third-party dependencies (no SPM packages, no
CocoaPods, no Carthage — `packageProductDependencies` is empty in
`Focal.xcodeproj/project.pbxproj`). Everything ships on-device via SwiftData.

Bundle ID `timothybrits.co.za.Focal`, dev team `YW3L7Q7A5A`, marketing
version `1.0` (`project.pbxproj` → `XCBuildConfiguration`). License:
PolyForm Noncommercial 1.0.0 (`LICENSE.md`) — noncommercial use only.

## Build & Test Commands

These match `.github/workflows/ci.yml` exactly (including
`CODE_SIGNING_ALLOWED=NO`, which CI relies on since the runner has no access
to the `YW3L7Q7A5A` signing team — use it locally too unless you're building
for a physical device you can sign for yourself):

```bash
# Build for simulator
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  /Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild \
  build -scheme Focal -destination 'platform=iOS Simulator,name=iPhone 17' \
  CODE_SIGNING_ALLOWED=NO

# Run all tests
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  /Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild \
  test -scheme Focal -destination 'platform=iOS Simulator,name=iPhone 17' \
  CODE_SIGNING_ALLOWED=NO

# Run a single unit test
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  /Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild \
  test -scheme Focal -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:FocalTests/TaskStoreTests/testMethodName \
  CODE_SIGNING_ALLOWED=NO
```

There is no linter or formatter in this repo — no `.swiftlint.yml`,
`.swiftformat`, or `.editorconfig` exists. `xcodebuild build`/`test` (with
its built-in warnings) is the only automated check, and it's also the only
CI job (`.github/workflows/ci.yml`: one `build-and-test` job on `macos-26`,
30 min timeout, uploads `TestResults.xcresult` + `xcodebuild.log` as an
artifact on every run, pass or fail).

CI (and thus a sandbox without Xcode, like this one may be) cannot run
`xcodebuild` at all — it's macOS/Xcode-only. If you can't invoke it, say so
rather than claiming a build/test pass.

## Project configuration facts worth knowing before you touch build settings

All from `Focal.xcodeproj/project.pbxproj`:

- `IPHONEOS_DEPLOYMENT_TARGET = 26.0`, `SWIFT_VERSION = 5.0`,
  `TARGETED_DEVICE_FAMILY = "1,2"` (iPhone + iPad — this is why `MainView`,
  `AllTasksView`, etc. all branch on `horizontalSizeClass == .regular` to
  cap content width at 600pt on iPad).
- **`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`** (paired with
  `SWIFT_APPROACHABLE_CONCURRENCY = YES`). Every type in this module is
  implicitly `@MainActor`-isolated unless marked `nonisolated` — this is why
  `TaskStore` and `NotificationManager` compile with no `@MainActor`
  annotation anywhere, and why `TaskStoreTests` (`FocalTests/TaskStoreTests.swift`)
  doesn't need `@MainActor` on the struct despite driving `TaskStore`
  synchronously. If you're used to Swift's traditional default (nonisolated
  unless annotated), this project inverts that — don't add `@MainActor`
  defensively, it's already the default, and don't assume a plain `struct`/
  `class` here is safe to use off the main thread.
- `CODE_SIGN_STYLE = Automatic`, `DEVELOPMENT_TEAM = YW3L7Q7A5A`. Simulator
  builds don't need signing (hence `CODE_SIGNING_ALLOWED=NO` above always
  works). Building for a physical device requires membership on that Apple
  Developer team, or changing `DEVELOPMENT_TEAM` locally — don't commit that
  change unless you mean to reassign the project.
- `STRING_CATALOG_GENERATE_SYMBOLS = YES` for the `Focal` target only (off
  for `FocalTests`/`FocalUITests`). No code currently references generated
  string symbols (`#Preview` doesn't exist anywhere in the codebase either —
  `ENABLE_PREVIEWS = YES` is set but unused).
- `packageProductDependencies` is empty on every target — there is no SPM
  dependency to add a new one next to; if you add a package, you're
  introducing the project's first.

## Code Style

- **Doc comments on public APIs only** — use `///` doc comments on public
  types (classes, structs, enums, protocols) and their public
  properties/methods to explain non-obvious behavior, invariants, or side
  effects. Skip them where the signature is already self-explanatory. No
  inline `//` implementation comments anywhere; keep code self-explanatory
  instead.
- The `FocalUITests` target exists but contains only Xcode's auto-generated
  stubs (`FocalUITests.swift`, `FocalUITestsLaunchTests.swift` — a launch
  test and a performance measurement, nothing app-specific). No UI tests to
  maintain; don't treat their absence as a gap.

## Architecture

Focal shows one task at a time to reduce ADHD decision paralysis. It uses
**SwiftData** for persistence and the `@Observable` macro (not
`ObservableObject`) for state management.

### Data layer

- `Focal/FocalTask.swift` — `@Model` type: `id`, `title`, `note`,
  `createdAt`, `completedAt`, `dueDate`, `estimatedMinutes`, `recurrence`,
  and a cascade-delete `subtasks` relationship (inverse of `SubTask.task`).
  `sortedSubtasks` returns them in creation order. Also defines `TaskLimit`
  (`titleMax: 80`, `noteMax: 300` — enforced by `LimitedTextField`, not by
  SwiftData itself) and `RecurrenceRule` (`daily`/`weekdays`/`weekly`/
  `monthly`, with `nextDate(from:)` and `nextDate(from:notBefore:)`).
- `Focal/SubTask.swift` — `@Model` type for a task's checklist items
  (`title`, `isCompleted`, `createdAt`, inverse `task` relationship).
- Due dates are always day-granularity: every picker that sets one starts
  from `Calendar.current.startOfDay(for: Date())`
  (`QuickAddSheet.swift`, `EditTaskSheet.swift`) — don't assume a `dueDate`
  carries a meaningful time component.

### State layer

- `Focal/TaskStore.swift` — `@Observable` class, the sole owner of all
  `FocalTask`/`SubTask` mutations. Owns the session queue: a randomised,
  non-repeating cycle of incomplete task IDs (`sessionQueue`), reseeded by
  `advance(with:)` whenever it runs dry — due-today/overdue tasks are
  shuffled and placed first, everything else shuffled after. `advance(with:)`
  accepts a pre-fetched list to skip a redundant SwiftData fetch.
  - Mutating API: `done()` / `done(taskID:)`, `notNow()`,
    `addTask(title:note:dueDate:estimatedMinutes:recurrence:subtaskTitles:)`,
    `deleteTask(_:)` / `undoDelete()` (5s undo window, 10s while VoiceOver
    or Switch Control is running — `UIAccessibility.isVoiceOverRunning` /
    `.isSwitchControlRunning`), `prioritizeTask(_:)` ("Focus now"),
    `restoreTask(_:)`, `addSubtask(to:title:)`, `deleteSubtask(_:)`,
    `updateSubtask(_:title:isCompleted:)`, `toggleSubtask(_:in:)`, and
    `completeIfAllSubtasksDone(_:)` (auto-completes a task once every
    subtask is checked off).
  - Completing a recurring task (`done`/`done(taskID:)`) spawns its next
    occurrence via `RecurrenceRule.nextDate(from:notBefore:)` **before**
    marking the original complete — the rollover preserves the rule's
    cadence anchor rather than resetting to "today": an overdue **daily**
    task rolls to today, but an overdue **weekly**/**monthly** task steps
    forward by its period from the original due date until landing on a
    non-past date, so it keeps the same weekday/day-of-month
    (`FocalTests/TaskStoreTests.swift`:
    `doneOnOverdueWeeklyRecurringTaskKeepsCadenceAnchor`).
  - Read-only state the UI depends on: `currentTask`/`currentTaskID`,
    `pendingUndo` (backs the undo banner), `notNowStreak` (consecutive
    `notNow()` calls, reset by `done(taskID:)`, `deleteTask(_:)`,
    `prioritizeTask(_:)`, or any queue reseed), `queueCleared` (increments
    each time the queue empties — drives `MainView`'s empty-state bounce
    animation), and
    `hasCompletedCycle` (`notNowStreak >= sessionQueue.count` — true once
    every queued task has been passed over at least once; `MainView` swaps
    its "N tasks" caption for "You've seen them all." when this is true).
- `Focal/NotificationManager.swift` — singleton wrapping
  `UNUserNotificationCenter` for the single inactivity-reminder
  notification. `TaskStore.updateInactivityNotification()` calls
  `reschedule()`/`cancelAll()` on every queue-changing action.
- `Focal/DefaultsKey.swift` — `DefaultsKey` enum: the single source of truth
  for all `UserDefaults`/`@AppStorage` key strings and color-scheme value
  constants. Add new persisted settings here, not as inline string literals.

### UI layer

- `Focal/FocalApp.swift` — creates `ModelContainer` (schema:
  `[FocalTask.self, SubTask.self]`) and `TaskStore` in `init()`, injects both
  into the environment. Owns `preferredScheme` from `@AppStorage`.
- `Focal/MainView.swift` — root view. Shows the current task card (title,
  note, subtask checklist, and estimate/due/recurrence meta badges) with
  Done / Not now buttons; animates task transitions (respects Reduce Motion
  and the in-app animations toggle). Hosts the undo banner. Done / Not now
  stack vertically at accessibility Dynamic Type sizes
  (`dynamicTypeSize.isAccessibilitySize`).
- `Focal/QuickAddSheet.swift` — sheet for adding a new task. A "More
  options" disclosure exposes due date, estimate, recurrence; a Subtasks
  section adds checklist items. Guards accidental dismissal with a discard
  confirmation once any field is non-empty.
- `Focal/EditTaskSheet.swift` — sheet for editing or deleting an existing
  task, including its scheduling fields and subtasks; saves task fields via
  `@Environment(\.modelContext)` directly, but routes subtask add/update/
  delete through `TaskStore` (`addSubtask`/`updateSubtask`/`deleteSubtask`).
  Guards unsaved changes with a discard confirmation.
- `Focal/AllTasksView.swift` — sheet listing all incomplete and completed
  tasks. Incomplete rows: tap to edit, long-press context menu for Done /
  "Focus Now" / Edit / Delete, swipe-right for "Focus now", swipe-left for
  Done / Delete. Completed rows: swipe-right to restore, swipe-left to
  delete. Opens Settings via the gear icon (pushed via
  `navigationDestination`, not a sheet).
- `Focal/SettingsView.swift` — notifications (inactivity threshold), color
  scheme, animations toggle.
- `Focal/LimitedTextField.swift` — reusable `TextField` with a live
  character counter (shown once within 20 characters of the limit, red at
  the limit) and a hard clamp via `onChange`. This — not SwiftData — is
  what actually enforces `TaskLimit.titleMax`/`noteMax`.

### Extensions

- `Focal/Extensions.swift` — `String.nilIfEmpty: String?` (empty string →
  nil) and `String.trimmed: String` (strips leading/trailing whitespace
  only — does not coerce to nil). Shared formatting helpers
  (`formatEstimateMinutes`, `formatDueDate` → `DueDateDisplay`,
  `metaBadge`), the `View.undoBanner(_:animate:onUndo:)` modifier, and
  reusable views: `EstimatePicker`, `RecurrencePicker`, `SubtaskInputField`,
  and `UndoBanner` (posts a VoiceOver announcement on appear via
  `AccessibilityNotification.Announcement`).

### Testing

- **Unit tests** (`FocalTests/TaskStoreTests.swift`) use **Swift Testing**
  (`import Testing`, `@Test`, `#expect`), not XCTest. All 46 tests live in
  one `TaskStoreTests` struct, each building an isolated in-memory
  `TaskStore` via the private `makeStore(tasks:)` helper
  (`ModelConfiguration(isStoredInMemoryOnly: true)`).
- To run a single test: `-only-testing:FocalTests/TaskStoreTests/methodName`
  (see Build & Test Commands above).
- `FocalUITests/` is stub-only (see Code Style above) — there is no UI test
  coverage of any actual screen.

## Localisation

The app currently ships **English only** (commits `8c1bb2d`, `d847bce`
removed Afrikaans/Spanish and fixed a README that still claimed
multilingual support — don't reintroduce that claim without also
reintroducing the localizations). The localisation infrastructure is kept
in place so languages can be added again later. Strings live in a single
`Focal/Localizable.xcstrings` file (Xcode String Catalog format), 86 keys,
`sourceLanguage` and only locale present is `en`.

- All user-facing strings — including UI labels, accessibility labels, and
  accessibility hints — flow through the catalog. English keys without an
  explicit `en` localization use the key itself as the source value
  (standard String Catalog behaviour).
- SwiftUI string literals (`Text("...")`, `.accessibilityLabel("...")`,
  etc.) are automatically resolved as `LocalizedStringKey` and look up the
  catalog.
- String interpolation with `\(variable)` produces a plain `String`, **not**
  a `LocalizedStringKey`. Use `Text("\(variable) key")` (the `Text`
  initialiser) or `String(localized:)` to keep interpolated strings
  localized.
- Plural rules use the `variations.plural` structure in xcstrings with
  `one`/`other` forms. Exactly three keys currently use it:
  `"%lld tasks"`, `"%lld characters remaining"`, `"Maximum %lld characters"`.
- **Adding a language again:** add its code to `knownRegions` in
  `Focal.xcodeproj/project.pbxproj` (only `en` and `Base` are listed now),
  then add a localization for that code under each key in
  `Localizable.xcstrings` (Xcode does this automatically when you select
  the language in the String Catalog editor). Run `xcodebuild` to catch
  missing keys early.

## Known platform quirks and gotchas

- iOS 26 uses `.glassEffect()` (Liquid Glass) — requires the iOS 26 SDK; no
  fallback path exists anywhere in the UI layer.
- iOS 27 ready while keeping the iOS 26 deployment target: the app already
  satisfies the iOS 27 SDK's mandatory scene-based lifecycle (SwiftUI `App`
  lifecycle + `UIApplicationSceneManifest_Generation`, no `AppDelegate`),
  never sets the deprecated `UIDesignRequiresCompatibility` Liquid Glass
  opt-out, and does no networking (so the stricter iOS 27 ATS/TLS 1.2+
  enforcement does not apply).
- Inject `@Observable` stores with `.environment(store)`, access with
  `@Environment(TaskStore.self)`. Do not use `ObservableObject`/
  `@StateObject` — nothing in this codebase does, and mixing paradigms
  would be a real gotcha for a future contributor copying an old tutorial.
- `PBXFileSystemSynchronizedRootGroup` in Xcode 26: files added to or
  deleted from `Focal/`, `FocalTests/`, or `FocalUITests/` are
  auto-included/excluded in the build — don't hand-edit
  `project.pbxproj` to add or remove a source file, it isn't necessary and
  the file list there is intentionally sparse (only product/group/build
  metadata, no per-file source entries).
- `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` — see "Project configuration
  facts" above. This is the single biggest way this project's concurrency
  behavior differs from a default Swift package.
- Recurring-task rollover preserves the cadence anchor, not "today" — see
  the State layer note above before changing `RecurrenceRule.nextDate`.

## Stale/historical docs — do not treat as current or actionable

`docs/superpowers/` contains implementation plans written for the
`superpowers` agent-skill workflow (each plan's header says "REQUIRED
SUB-SKILL: superpowers:subagent-driven-development"). None of them are wired
into this repo's own tooling (no `.claude/` config here) — they're artifacts
from past sessions, not live specs:

- **`docs/superpowers/plans/2026-05-21-focal-app.md`** — the *original* v1
  build plan. Mostly historical: it predates subtasks, due dates, estimates,
  recurrence, undo/delete, VoiceOver/Switch Control handling, and iPad
  layout — none of which it mentions, all of which now exist. Specific
  details in it no longer match the code: it describes a `FocalTask.lastSkippedAt`
  field (replaced by `TaskStore.notNowStreak`, which lives on the store, not
  the model), a public `TaskStore.refreshIfNeeded()` (now `private`), a
  single-model schema (`[FocalTask.self]` — now
  `[FocalTask.self, SubTask.self]`), and `Item.swift`/`ContentView.swift`
  (deleted/renamed to `MainView.swift` long ago). Treat it as history, not
  as something to resume.
- **`docs/superpowers/plans/2026-05-22-done-confetti.md`** and
  **`docs/superpowers/specs/2026-05-22-done-confetti-design.md`** — a
  confetti-burst-on-Done feature, spec status "Approved." **This was never
  implemented.** There is no `Focal/ConfettiView.swift`, no
  `showingConfetti` state, no `CAEmitterLayer` usage anywhere in the repo
  (verified by grep across all `.swift` files). The plan's own snippets are
  already out of sync with current code — it shows the Done button calling
  `UINotificationFeedbackGenerator().notificationOccurred(.success)`
  directly, but `MainView.swift`'s Done button now triggers haptics via the
  SwiftUI `.sensoryFeedback(.success, trigger: successTrigger)` modifier
  instead, so the plan's "replace this block" diff no longer applies
  verbatim. If asked to build this feature, treat the spec as a starting
  design intent only, re-diff against current `MainView.swift`, and confirm
  the product decision (confetti-on-Done) is still wanted before
  implementing — don't assume "Approved" still reflects current intent
  months later.

None of these three files should be deleted without asking first — they're
not hazardous (nothing on disk would execute them automatically), just
outdated.
