# Focal

A focused task manager for iOS and iPadOS designed to reduce ADHD decision paralysis. Focal shows you **one task at a time** — tap **Done** to complete it, or **Not now** to shuffle it to the back of the queue and see something else.

No lists. No prioritising. Just the next thing.

## Features

- One task at a time — no overwhelming backlogs
- Randomised queue that cycles through all your tasks fairly
- Optional inactivity reminders (2 h / 4 h / 8 h)
- Light, Dark, and System appearance
- Task transition animations with Reduce Motion support
- Title limit: 80 characters · Note limit: 300 characters
- Localised in English, Afrikaans, and Spanish

## Requirements

- iOS 26+ / iPadOS 26+
- Xcode 26+

## Building

Open `Focal.xcodeproj` in Xcode and run on a simulator or device, or via the command line:

```bash
xcodebuild build \
  -scheme Focal \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  CODE_SIGNING_ALLOWED=NO
```

## Running Tests

```bash
xcodebuild test \
  -scheme Focal \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```

## License

[PolyForm Noncommercial 1.0.0](LICENSE.md) — free for personal and non-commercial use.
