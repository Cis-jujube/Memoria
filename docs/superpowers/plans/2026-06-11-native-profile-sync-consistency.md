# Native Profile Sync Consistency Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make Memoria profiles, bilingual copy, local native apps, web reference, calendar visualization, and future account sync point in one consistent product direction.

**Architecture:** Add a shared person profile field contract to each local platform model and SQLite table. Keep API keys device-local, while account sync is a separate self-hosted service boundary for the user's mainland China server.

**Tech Stack:** SwiftUI + SQLite3 + Keychain, Android Java native views + SQLiteOpenHelper + Keystore, Tauri React/TypeScript + Rust/rusqlite/keyring, Next.js reference UI + Prisma.

---

### Task 1: Shared Person Profile Fields

**Files:**
- Modify: `src/data/demo.ts`
- Modify: `ios/Memoria/Models.swift`
- Modify: `ios/Memoria/DemoData.swift`
- Modify: `ios/Memoria/LocalSQLiteStore.swift`
- Modify: `macos/Sources/MemoriaMac/Models/DashboardModels.swift`
- Modify: `macos/Sources/MemoriaMac/Persistence/LocalSQLiteStore.swift`
- Modify: `android/app/src/main/java/com/jujube/memoria/data/FriendPerson.java`
- Modify: `android/app/src/main/java/com/jujube/memoria/data/LocalDatabase.java`
- Modify: `android/app/src/main/java/com/jujube/memoria/data/DashboardStore.java`
- Modify: `windows/src/App.tsx`
- Modify: `windows/src-tauri/src/lib.rs`

- [x] Add fields: dietaryRestrictions, favoriteFoods, dislikedThings, zodiacSign, mbti, interests, books, sports, profileTags.
- [x] Seed demo people with the same semantic facts across platforms.
- [x] Add SQLite migration columns with default empty values.

### Task 2: Profile UI Consistency

**Files:**
- Modify: `src/components/app/friend-command-center.tsx`
- Modify: `ios/Memoria/PeopleView.swift`
- Modify: `macos/Sources/MemoriaMac/Views/PeopleView.swift`
- Modify: `android/app/src/main/java/com/jujube/memoria/MainActivity.java`
- Modify: `windows/src/App.tsx`

- [x] Show identity fields, preference fields, interests/books/sports, and source memory.
- [x] Use Chinese copy when language is Chinese; avoid direct machine-translation wording.

### Task 3: Calendar Visualization

**Files:**
- Modify: `ios/Memoria/Models.swift`
- Modify: `ios/Memoria/RootView.swift`
- Create or modify iOS Calendar view.
- Confirm macOS/web existing calendar views remain wired.
- Add Android and Windows calendar sections if missing.

- [x] Show birthdays, reminders, and study/work events as a simple timeline/list visualization.
- [x] Keep values visible without hover.

### Task 4: Account Sync Architecture

**Files:**
- Create: `docs/account-sync-mainland-server.md`
- Modify: `README.md`

- [x] Define free account registration, self-hosted China server deployment, sync API surface, auth/session model, and conflict policy.
- [x] State that DeepSeek API keys stay local and are not synced.

### Task 5: Verification

**Commands:**
- `pnpm test`
- `pnpm typecheck`
- `pnpm lint`
- `pnpm build`
- `swift build` in `ios/`
- `swift build` in `macos/`
- Android compile if Maven is reachable
- Windows Rust check if cargo is installed

- [x] Report exact passes and environment blockers.
