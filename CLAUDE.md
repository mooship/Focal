# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Test Commands

```bash
# Build for simulator
xcodebuild build -scheme Focal -destination 'platform=iOS Simulator,name=iPhone 16'

# Run all tests
xcodebuild test -scheme Focal -destination 'platform=iOS Simulator,name=iPhone 16'

# Run a single unit test
xcodebuild test -scheme Focal -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:FocalTests/FocalTests/example

# Run a single UI test
xcodebuild test -scheme Focal -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:FocalUITests/FocalUITests/testExample
```

## Architecture

Focal is a SwiftUI iOS app using **SwiftData** for persistence. The data stack is wired up in `FocalApp.swift`, which creates a `ModelContainer` for all `@Model` types and injects it into the SwiftUI environment via `.modelContainer(sharedModelContainer)`. Views access storage through `@Environment(\.modelContext)` and `@Query`.

### Data layer
- `Item.swift` — the only SwiftData model. Add new persistent types here and register them in the `Schema([...])` array in `FocalApp.swift`.

### UI layer
- `ContentView.swift` — root view; uses `NavigationSplitView` with a sidebar list of items and a detail pane.

### Testing
- **Unit tests** (`FocalTests/`) use **Swift Testing** (`import Testing`, `@Test` functions, `#expect`).
- **UI tests** (`FocalUITests/`) use **XCTest** / `XCUIApplication`.
