# Review UI QA Evidence

Date: 2026-06-19

## Automated Gates

- `swift run MemoriaProtocolChecks`
  - Parses `macos/Tests/Fixtures/review_ui_pending_updates.json`
  - Verifies the six required Review Desk scenarios have stable ids, proposal types, v1.1 pending payload metadata, and expected labels
- `swift build`
  - Compiles the macOS Review Desk UI including candidate selection, approval gating, skip/focus handling, undo banner, and People detail correction menus
- `bash ./script/build_and_run.sh --verify`
  - Builds `Memorial` and runs `MemoriaProtocolChecks`

## Scenario Coverage

- Overview with three review categories
- Friend fact with old value vs new suggestion
- Schedule reminder with unclear date
- Gift signal with high-risk tags
- Schema failure messaging
- Candidate people ambiguity
- Sensitive self-reflection

## Manual QA Checklist Status

The checklist in `docs/REVIEW_INBOX_QA.md` is the manual script for window-size
and VoiceOver verification. Screenshots are expected in this directory using
the names listed there. No screenshot files are committed in this pass because
the current automated validation path is SwiftPM-based rather than XCUITest or
screen-capture based.

This evidence file exists so future PR review can distinguish:

- implemented and protocol-checked behavior, and
- remaining manual screenshot capture work before a visual release signoff.
