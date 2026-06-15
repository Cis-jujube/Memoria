# Codex Audit: Memoria macOS V1.5

## Scope

This audit covers the macOS-first Personal Memory Core work requested in
`docs/MEMORIA_MACOS_CODEX_MASTER_SPEC.md`. At initial audit time the repo-local
spec was missing and the source document was found at
`/Users/zaozaowang/Downloads/MEMORIA_MACOS_CODEX_MASTER_SPEC.md`; Phase 1 copied
it into `docs/`.

Primary target for this implementation: `macos/`.

Reference-only target: Web app in `src/`.

Paused targets: `ios/`, `android/`, and `windows/`.

## Current macOS Files

- `macos/Package.swift` defines a SwiftPM executable product named
  `MemoriaMac` for macOS 14 and links `sqlite3`.
- `macos/Sources/MemoriaMac/App/MemoriaMacApp.swift` is the SwiftUI app
  entrypoint.
- `macos/Sources/MemoriaMac/App/AppDelegate.swift` handles AppKit activation.
- `macos/Sources/MemoriaMac/Views/ContentView.swift` uses
  `NavigationSplitView`.
- `macos/Sources/MemoriaMac/Views/SidebarView.swift` owns the sidebar.
- `macos/Sources/MemoriaMac/Views/DetailView.swift` switches between current
  sections.
- Existing views cover overview, inbox, people, calendar, reminders, gifts,
  search, relationship map, files, and settings.
- `macos/Sources/MemoriaMac/Stores/DashboardStore.swift` is the central
  observable state object and mutation coordinator.

## Database Files

- `macos/Sources/MemoriaMac/Persistence/LocalSQLiteStore.swift` owns SQLite
  open, migration, seed, reads, and writes.
- The implemented schema includes:
  - `schema_migrations`
  - `app_settings`
  - `people`
  - legacy `memories`
  - schema-v2 `raw_entries`
  - schema-v2 `memory_atoms`
  - schema-v2 generic `pending_updates`
  - `themes`
  - `memory_person_links`
  - `memory_theme_links`
  - `ai_runs`
  - `audit_events`
  - `reminders`
  - `gift_ideas`
- Legacy `pending_updates` rows are adapted by renaming the old table to
  `pending_updates_legacy` and creating protocol-shaped pending proposal rows.
- Capture saves `RawEntry` first, then creates `PendingUpdate` proposal rows.

## AI Files

- `macos/Sources/MemoriaMac/Services/LocalAI.swift` defines:
  - `DeepSeekModel`
  - `NativeSettings`
  - copy strings
  - request/response structs
  - `DeepSeekClient`
- `AIWorkflowService` provides deterministic mocked extraction for local Phase
  0-4 verification and optional real DeepSeek extraction when a Keychain key is
  present.
- `AIJSONParser` and `AIContractValidator` validate `extract_memory` JSON before
  proposal persistence.
- Extraction returns protocol `PendingUpdate` rows with `proposal_type` and
  `payload_json`.
- API key persistence is in
  `macos/Sources/MemoriaMac/Services/SecureAPIKeyStore.swift` using Keychain.

## Current UI Sections

The implemented macOS information architecture is:

- 总览: 首页
- 工作流: 记录, 整理台
- 三种模式: 自我检索, 朋友档案管理, 行程安排
- 系统: 设置

`记录` uses a single-choice `WorkspaceMode` segmented picker. Submitting a record opens `整理台` with the matching `ReviewCategory`. Opening `整理台` from the sidebar calls `openReviewDesk(category: nil)` and shows the review overview.

## Current Build and Test Commands

- `swift build` from `macos/` succeeds.
- `swift test` from `macos/` currently fails because no test target exists.
- `./script/build_and_run.sh` builds the SwiftPM product, stages
  `dist/MemoriaMac.app`, and launches it.
- `./script/build_and_run.sh --verify` builds the SwiftPM product and runs the
  executable's verification mode without launching the app bundle.

## Risks

- The local CommandLineTools Swift install does not provide `XCTest` or Swift
  `Testing`, so Phase 0-4 verification uses the SwiftPM executable
  `MemoriaProtocolChecks`.
- DeepSeek API calls must remain behind Keychain-stored keys and must never log
  or persist the API key.
- Real DeepSeek extraction depends on network and user-provided API key state;
  the mocked workflow is the reliable local verification path.
- iOS, Android, and Windows are intentionally not expanded in this phase.

## Implementation Plan

1. Package structure now exposes `MemoriaCore` plus the `MemoriaMac`
   executable.
2. Fixtures and `MemoriaProtocolChecks` cover:
   - schema v2 migration
   - RawEntry repository create/fetch
   - PendingUpdate proposal create/list
   - approval creating MemoryAtom and links
   - AI JSON parser valid/invalid responses
   - memory search filtering
3. Docs exist for Memory Protocol, AI contract, macOS-first native scope,
   design system, and manual QA.
4. Schema v2 migration is non-destructive and adapts legacy pending rows.
5. Domain models and repositories exist for RawEntry, MemoryAtom, PendingUpdate,
   Theme, and memory links.
6. AI workflow skeleton uses mocked extraction by default when no API key is
   present and DeepSeek JSON calls when a Keychain key is present.
7. macOS navigation is re-mapped to 首页, 记录, 整理台, 自我检索,
   朋友档案管理, 行程安排, and 设置.
8. 记录 saves RawEntry before AI work and creates PendingUpdates.
9. 整理台 approve/edit/reject is per-item; approve creates confirmed
   MemoryAtoms and reject does not mutate final memory.
10. Verification commands are `swift run MemoriaProtocolChecks`, `swift build`,
   and `./script/build_and_run.sh --verify`. `swift test` reports no tests found
   on this machine because XCTest/Swift Testing are unavailable.
