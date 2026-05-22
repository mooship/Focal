# Done Confetti Celebration — Design Spec

**Date:** 2026-05-22
**Status:** Approved

## Summary

Add a brief confetti burst when the user taps Done, giving positive feedback before the next task appears. The celebration is purely visual (plus the existing haptic), lasts under two seconds, and is skipped entirely when animations are disabled or Reduce Motion is on.

## User-Visible Flow

1. User taps **Done**
2. `.success` haptic fires (existing behaviour, unchanged)
3. Full-screen confetti overlay appears instantly
4. 0.7s later, `store.done()` is called — task slides out as normal
5. Confetti overlay fades out after ~1.5s total (particles have settled)

If `shouldAnimate` is `false`, step 3–5 are skipped and `store.done()` is called immediately, exactly as today.

## New Component: `ConfettiView`

**File:** `Focal/ConfettiView.swift`

A `UIViewRepresentable` that hosts a `CAEmitterLayer` inside a `UIView`.

### Emitter configuration

- **Position:** horizontal line across the top third of the screen (`y = bounds.height * 0.3`)
- **Shape:** `.line`, spanning full screen width
- **Burst duration:** emitter fires for 0.4s then `birthRate` drops to 0 — particles fall and fade naturally, no looping

### Particle cells (6–8 colours)

| Property | Value |
|---|---|
| Shape | small rectangle, ~8×5pt |
| Colours | red, orange, yellow, green, blue, purple, pink, white |
| Initial velocity | ~300pt/s downward |
| Velocity range | ±150pt/s (spread) |
| Emission longitude | π/2 (straight down) + ±π/4 range |
| Spin | random, ~2π rad/s |
| Lifetime | 2.0s |
| Fade | `alphaSpeed = -0.5` (fades out over lifetime) |
| Scale | 0.06 |

### Lifecycle

`makeUIView` creates the view and layer. `updateUIView` does nothing. The layer is added once and fires immediately on creation — the SwiftUI parent controls visibility via conditional rendering.

## Changes to `MainView`

### New state

```swift
@State private var showingConfetti = false
```

### Done button action (replaces current)

```swift
UINotificationFeedbackGenerator().notificationOccurred(.success)
if shouldAnimate {
    showingConfetti = true
    Task {
        try? await Task.sleep(for: .seconds(0.7))
        store.done()
        try? await Task.sleep(for: .seconds(1.5))
        showingConfetti = false
    }
} else {
    store.done()
}
```

### Overlay (added to `NavigationStack`)

```swift
.overlay {
    if showingConfetti {
        ConfettiView()
            .ignoresSafeArea()
            .allowsHitTesting(false)
            .transition(.opacity)
    }
}
```

The overlay uses `.allowsHitTesting(false)` so the confetti doesn't block any taps during its lifetime.

## Files Changed

| File | Change |
|---|---|
| `Focal/ConfettiView.swift` | New — `UIViewRepresentable` wrapping `CAEmitterLayer` |
| `Focal/MainView.swift` | Add `@State var showingConfetti`, update Done button action, add confetti overlay |

## Out of Scope

- Sound effects
- Haptic pattern changes
- Confetti on task restore or any other action
- User control over confetti (always on when animations are enabled)
