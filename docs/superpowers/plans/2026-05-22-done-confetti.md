# Done Confetti Celebration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show a confetti burst full-screen for ~2.2s when the user taps Done, briefly delaying the task transition, with no change in behaviour when animations are off.

**Architecture:** A new `ConfettiView` (`UIViewRepresentable` wrapping a `CAEmitterLayer`) is conditionally rendered as a full-screen overlay in `MainView`. The Done button sets `showingConfetti = true`, waits 0.7s before calling `store.done()`, then clears the overlay 1.5s later. The `fired` guard on the backing `UIView` ensures the emitter fires exactly once per view instantiation.

**Tech Stack:** SwiftUI, UIKit (`CAEmitterLayer`, `UIGraphicsImageRenderer`), Swift Concurrency (`Task`, `Task.sleep`)

---

### Task 1: Create ConfettiView

**Files:**
- Create: `Focal/ConfettiView.swift`

- [ ] **Step 1: Create the file**

Create `Focal/ConfettiView.swift` with the following content:

```swift
import SwiftUI
import UIKit

struct ConfettiView: UIViewRepresentable {
    func makeUIView(context: Context) -> ConfettiUIView { ConfettiUIView() }
    func updateUIView(_ uiView: ConfettiUIView, context: Context) {}
}

final class ConfettiUIView: UIView {
    private let emitter = CAEmitterLayer()
    private var fired = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        layer.addSublayer(emitter)
        emitter.emitterShape = .line
        emitter.emitterCells = Self.makeCells()
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard !fired, bounds.size != .zero else { return }
        fired = true
        emitter.emitterPosition = CGPoint(x: bounds.midX, y: bounds.height * 0.3)
        emitter.emitterSize = CGSize(width: bounds.width, height: 1)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            self?.emitter.birthRate = 0
        }
    }

    private static func makeCells() -> [CAEmitterCell] {
        let colors: [UIColor] = [
            .systemRed, .systemOrange, .systemYellow, .systemGreen,
            .systemBlue, .systemPurple, .systemPink, .white
        ]
        let image = confettiImage()
        return colors.map { color in
            let cell = CAEmitterCell()
            cell.birthRate = 10
            cell.lifetime = 2.0
            cell.velocity = 300
            cell.velocityRange = 150
            cell.emissionLongitude = .pi / 2
            cell.emissionRange = .pi / 4
            cell.spin = 2 * .pi
            cell.spinRange = .pi
            cell.yAcceleration = 150
            cell.scale = 0.06
            cell.scaleRange = 0.02
            cell.alphaSpeed = -0.5
            cell.color = color.cgColor
            cell.contents = image.cgImage
            return cell
        }
    }

    private static func confettiImage() -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 8, height: 5)).image { ctx in
            UIColor.white.setFill()
            UIBezierPath(rect: CGRect(x: 0, y: 0, width: 8, height: 5)).fill()
        }
    }
}
```

- [ ] **Step 2: Build to confirm it compiles**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  /Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild \
  build -scheme Focal -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED"
```

Expected: `BUILD SUCCEEDED` with no errors.

- [ ] **Step 3: Commit**

```bash
git add Focal/ConfettiView.swift
git commit -m "feat: add ConfettiView backed by CAEmitterLayer"
```

---

### Task 2: Wire ConfettiView into MainView

**Files:**
- Modify: `Focal/MainView.swift`

- [ ] **Step 1: Add the showingConfetti state property**

In `MainView`, add a new `@State` property after the existing `@State private var editingTask` line (currently line 12):

```swift
@State private var showingConfetti = false
```

- [ ] **Step 2: Replace the Done button action**

Find this block in `taskView(_:)`:

```swift
                    Button {
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                        store.done()
                    } label: {
                        Text("Done")
```

Replace it with:

```swift
                    Button {
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
                    } label: {
                        Text("Done")
```

- [ ] **Step 3: Add the confetti overlay**

The `body` property ends with `.sheet(item: $editingTask) { task in EditTaskSheet(task: task) }`. Add two more modifiers after it, before the closing `}` of `body`:

```swift
        .overlay {
            if showingConfetti {
                ConfettiView()
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.4), value: showingConfetti)
```

- [ ] **Step 4: Run all tests**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  /Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild \
  test -scheme Focal -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | grep -E "Test case|BUILD FAILED|TEST FAILED|TEST SUCCEEDED"
```

Expected: all existing `TaskStoreTests` cases pass, no build errors.

- [ ] **Step 5: Commit**

```bash
git add Focal/MainView.swift
git commit -m "feat: show confetti burst on Done before advancing to next task"
```
