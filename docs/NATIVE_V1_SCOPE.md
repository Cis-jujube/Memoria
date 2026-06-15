# Native V1.5 Scope

## Primary Runtime

macOS is the only active implementation target for this phase.

## Reference Runtime

The web app remains a visual and interaction reference. It is not the primary
runtime for this phase and should not drive data-model compromises.

## Paused Targets

iOS, Android, and Windows are not expanded in Phase 0-4. Existing files are left
untouched unless a shared contract must be documented.

## Phase 0-4 Deliverable

The deliverable is a working macOS local-first memory core:

```text
记录
-> selected mode: 自我检索 / 朋友档案管理 / 行程安排
-> RawEntry
-> mocked or DeepSeek extract_memory
-> PendingUpdate
-> 整理台 approve/edit/reject
-> confirmed MemoryAtom
```

## macOS V1.6 UX Additions

- Sidebar IA is explicit: 总览, 工作流, 三种模式, and 系统.
- `记录` is the only write entry for free-form capture and always asks the user to pick one of the three modes.
- `整理台` has an overview plus the three mode partitions; sidebar entry opens overview, record submission opens the selected partition.
- People groups are usable: a person can be moved between groups and the group
  filter immediately reflects the change.
- Each friend has a dossier page covering the requested 25 profile categories,
  manual closeness level, AI-assisted closeness signals, relationship map, and
  scored gift recommendations.
- Actions is a today-first reminder center for real appointments, birthdays,
  exams, interviews, travel, deadlines, and recurring check-ins.
- Search is Chinese-first when language is set to 中文 or follows a Chinese
  system locale; English remains available through the language setting.
- Memory Palace classifies confirmed memories by MemoryAtom type.

## Explicit Non-Goals

- cross-device sync
- cloud accounts
- notarization or App Store packaging
- OCR/PDF import expansion
- iOS/Android/Windows feature parity
- 3D relationship graph work
- automatic contacts sync
