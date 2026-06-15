# Memoria iOS

This folder contains the local native SwiftUI iOS app for Memoria. The app uses local SQLite for relationship data and Keychain for the user's DeepSeek API key.

`Package.swift` exposes the views, models, and demo data as an iOS 17 Swift package that Xcode can open directly. `Memoria/MemoriaApp.swift` is kept as the app entrypoint source for a full Xcode iOS App target.

See `../docs/native-companion-scope.md` for the shared native-local scope.

## What is included

- `Today` focus dashboard with relationship health metrics backed by SQLite seed/load.
- `AI Inbox` / `待确认` review flow with local confirm/discard behavior.
- `People` list with group filters and next-action hints.
- `Search` surface with local cited results.
- `Files` import status queue.
- `Settings` tab for DeepSeek model, deep thinking, API key, language, and privacy notes.

Quick Capture writes a local memory first. If a key is saved, it calls DeepSeek and places the result in AI Inbox for review.

## How to run in Xcode

1. Install full Xcode if it is not installed.
2. Point command line tools at Xcode:

   ```bash
   sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
   ```

3. Open `ios/Package.swift` in Xcode to inspect and preview reusable views.
4. For a full app bundle, create a new iOS App project named `Memoria`.
5. Add the Swift files in `ios/Memoria` to the app target, including `MemoriaApp.swift`.
6. Set the deployment target to iOS 17 or newer.
7. Build and run on an iPhone simulator.

## Local verification used here

This workspace verifies the Swift package with `swift build`. Full simulator/device QA still needs Xcode.
