# Memoria Agent Guide

## Active Scope

- Treat macOS as the active implementation target for this phase.
- Treat the web app as a visual/API reference unless the user explicitly asks for web work.
- Do not change database schema, AI JSON schema, auth, sync, or cloud deployment just to adjust navigation or copy.

## macOS Product Loop

- Sidebar groups must stay visible as: 总览, 工作流, 三种模式, 系统.
- 工作流 contains the two primary entries: 记录 and 整理台.
- 三种模式 contains: 自我检索, 朋友档案管理, 行程安排.
- 记录 uses a single-choice `WorkspaceMode` segmented picker.
- Submitting 记录 opens 整理台 with the selected `ReviewCategory`.
- Opening 整理台 from the sidebar must show the overview, with `selectedReviewCategory == nil`.
- Overview quick-record affordances should navigate to 记录 instead of writing a default-mode record directly.

## Current Verification

Run these after macOS behavior changes:

```bash
cd macos
swift run MemoriaProtocolChecks
swift build

cd ..
bash ./script/build_and_run.sh --verify
```

Use `bash ./script/build_and_run.sh` from the repository root to build and open `dist/Memorial.app`.

If direct app `--verify` launches hang at dyld startup on this local macOS install, stop the stuck process and use `swift run MemoriaProtocolChecks` plus `swift build` as the reliable code-level gate. Do not treat that dyld hang as a Memory Protocol failure unless the Swift checks fail. The project script's `--verify` mode now uses `MemoriaProtocolChecks` directly.

## Safety Boundaries

- DeepSeek keys stay in platform secure storage, not SQLite, docs, logs, fixtures, or source.
- AI may create `PendingUpdate` proposals; confirmed memory/profile/reminder changes require user approval.
- Keep the visual tone Quiet Premium: private, calm, source-backed, and not CRM-like.
