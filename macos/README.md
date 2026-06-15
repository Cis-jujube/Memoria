# Memorial

Native macOS app for the Memoria friend memory command center. The app bundle, process, and window name are `Memorial`.

This app uses local SQLite for relationship data and Keychain for the user's DeepSeek API key. See `../docs/native-companion-scope.md`.

## Structure

- `Package.swift` defines a SwiftPM macOS executable product.
- `Sources/MemoriaMac/App` contains the app entrypoint and AppKit activation delegate.
- `Sources/MemoriaMac/Models` contains navigation groups, workspace modes, review categories, and dashboard value models.
- `Sources/MemoriaMac/Stores` owns local SQLite-backed state and mutations.
- `Sources/MemoriaMac/Persistence` owns SQLite schema and seed/load behavior.
- `Sources/MemoriaMac/Services` owns DeepSeek request construction and Keychain storage.
- `Sources/MemoriaMac/Views` contains desktop SwiftUI surfaces.
- `Sources/MemoriaMac/Support` contains shared view styling and chart helpers.

## Current Information Architecture

The sidebar exposes the product loop directly:

- 总览: `首页`
- 工作流: `记录`, `整理台`
- 三种模式: `自我检索`, `朋友档案管理`, `行程安排`
- 系统: `设置`

`记录` uses a single-choice segmented mode picker. Submitting a record opens `整理台` in the matching mode partition. Opening `整理台` from the sidebar shows the overview partition.

## Run

From the repository root:

```bash
./script/build_and_run.sh
```

Verification mode:

```bash
./script/build_and_run.sh --verify
```

If repeated local `--verify` launches hang before app code starts, use `swift run MemoriaProtocolChecks` and `swift build` from `macos/`; this points to a local dyld/LaunchServices policy issue rather than a Memory Protocol failure.

The script builds the SwiftPM package, stages `dist/Memorial.app`, and launches the app bundle with `open -n`. If LaunchServices immediately exits the staged bundle on this local machine, the script falls back to opening the SwiftPM debug executable.

## Current boundary

The `记录` page writes local raw entries and creates reviewable `整理台` updates. With a saved key, the app calls DeepSeek directly from the local machine. Without a key, it keeps an honest local pending update and asks the user to configure Settings.
