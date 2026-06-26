# Memoria Memory Protocol

Memoria treats AI as an organizer, not a source of truth.

## Core Flow

```text
Free-form input
-> User selects one record mode: 自我检索 / 朋友档案管理 / 行程安排
-> RawEntry is saved locally
-> AI proposes structured PendingUpdate rows
-> PendingUpdate appears in 整理台 overview or the selected mode partition
-> User approves, edits, or rejects each proposal
-> Approved proposals become confirmed MemoryAtom rows
-> People, themes, actions, and Ask views derive from confirmed memory
```

## Core Records

- `RawEntry`: immutable source input. It stores what the user typed or imported
  before interpretation.
- `PendingUpdate`: AI or workflow proposal. It stores `proposal_type`,
  `payload_json`, confidence, status, and decision metadata.
- `MemoryAtom`: confirmed source-backed memory. It requires either
  `source_entry_id` or `source_quote`.
- `FriendPerson.category_notes_json`: local structured profile notes keyed by
  the shared 25-category person profile schema.
- `relationship_edges`: persisted person-to-person or person-to-external-node
  edges for partners, family, close friends, conflicts, mentors, and other
  relationship-map facts.
- `gift_ideas`: scored gift recommendation directions with rationale, risk,
  confirmation question, match score, surprise score, risk level, practicality,
  emotional value, and more-information flag.
- `Theme`: reusable long-term memory theme.
- `memory_person_links`: links confirmed memory to existing people.
- `memory_theme_links`: links confirmed memory to themes.

## Invariants

- AI never writes confirmed memory, people, reminders, gifts, or relationship
  levels directly.
- Every final memory must be source-traceable.
- Sensitive/private memories are visually marked and hidden from default search
  unless the caller explicitly includes them.
- Approval is the user signature for a memory transaction.
- DeepSeek API keys are stored only in Keychain and never in SQLite.
- Record mode routes a proposal to the right review partition; it does not let AI bypass user approval.
- AI schema metadata and structured reminder/gift/profile context are stored in
  `pending_updates.payload_json` as a compatible envelope. They do not require
  new SQLite columns in this phase.
- Relationship closeness has two layers: a manual level from 1-6 and
  AI-assisted signals. AI may suggest signals, but it does not directly change
  the manual level.
- Gift recommendations include scores and risks; they are recommendations, not
  confirmed facts.

## Current Phase 0-4 Implementation

- macOS is the only primary runtime.
- `LocalSQLiteStore` applies schema v2 non-destructively.
- `RawEntryRepository`, `PendingUpdateRepository`, `MemoryRepository`, and
  `ThemeRepository` implement the local protocol.
- `AIWorkflowService` supports deterministic mocked extraction for local
  workflow verification and optional DeepSeek extraction when a Keychain API key
  is present.
- `extract_memory v1.0` outputs without version metadata remain readable.
  `extract_memory v1.1` outputs add `schema_version`, `contract_name`,
  structured `reminder_proposals`, structured `gift_signal_proposals`, and
  minimal `value_struct` for birthdays/anniversaries, dietary/allergy notes, and
  contact details.
- Unknown `extract_memory` versions, wrong contract names, unknown JSON keys, or
  out-of-range confidence values fail closed. The saved `RawEntry` remains
  local, and invalid model output does not become `PendingUpdate` or confirmed
  memory.
- 记录 -> 整理台 -> approve creates a confirmed `MemoryAtom`.
- The macOS sidebar groups are 总览, 工作流, 三种模式, and 系统. The workflow entries are 记录 and 整理台; the mode entries are 自我检索, 朋友档案管理, and 行程安排.

## Pending Payload Envelope

Legacy `PendingUpdate.payload_json` may still be a direct
`MemoryAtomProposal` or `PersonProfilePatchProposal`.

New structured proposals may use:

```json
{
  "payload_schema_version": "1.1",
  "payload_contract_name": "pending_update_payload",
  "proposal_kind": "memory_atom",
  "proposal": {},
  "structured_context": {},
  "review_explanation": {},
  "freshness": {},
  "approval_result": null,
  "undo": null
}
```

The `proposal` field remains the full legacy Codable proposal used by display,
edit, and approval paths. `structured_context`, `review_explanation`, and
`freshness` only enrich review, editing, explanation, and future undo behavior.
They are not a new write path.

## Current Product Additions

- People groups are writable and can move a person between classmate,
  study-abroad, home-friend, and internship/career groups.
- Each person has a dossier page with basic info, relationship context,
  interests, food/lifestyle, education/career, life events, files, AI
  inference, and a relationship map.
- Relationship-map additions are written to local SQLite instead of demo-only
  state.
- Gift recommendations can be generated from a selected person profile and a
  natural-language request such as a budgeted birthday-gift prompt.
- Today reminder plans can be synchronized into macOS local notifications.
- 自我检索 supports category and theme filtering for confirmed reflection-style memories and a timeline-style square of saved self notes.
- 朋友档案管理 owns people dossiers, approved profile facts, relationship context, and friend-linked proposals.
- 行程安排 owns reminder-like proposals, today's actions, birthdays, exams, meetings, trips, deadlines, and recurring check-ins.
- Actions is a today-first reminder center rather than a generic count board.
