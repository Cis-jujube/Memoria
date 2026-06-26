# Review Desk QA Checklist

This checklist covers the v1.1 Review Desk work from
`docs/AI_SCHEMA_OPTIMIZATION_EXECUTABLE_REPORT.md`.

## Fixture

- Source fixture: `macos/Tests/Fixtures/review_ui_pending_updates.json`
- Screenshot output: `macos/TestArtifacts/ReviewUI/`
- Required widths: 1280x840, 900x720, 640x720, 520x720

## Manual Pass Criteria

- Overview shows 自我检索, 朋友档案管理, and 行程安排 queues.
- Source text is collapsed by default and labelled 来自这句话.
- Buttons appear as 编辑, 批准, 拒绝.
- Reject reason field is visible and optional.
- Unclear reminder dates disable approval until edited.
- Candidate-person ambiguity disables approval until a target is selected.
- High-risk gift signals require risk acknowledgement before approval.
- Profile patches show old-value/new-suggestion context and editable category/value fields.
- Contact, health/allergy, and sensitive content stay masked or summarized in list context.
- VoiceOver order follows summary, source disclosure, edit, approve, reject.
- Narrow widths have no horizontal scrolling and no truncated action text.
- Recent approval exposes 撤销刚才的保存, and undo keeps the original RawEntry.

## Screenshot Names

Use stable names when capturing:

- `overview-1280.png`
- `friend-fact-640.png`
- `reminder-unclear-date-640.png`
- `gift-risk-640.png`
- `same-name-640.png`
- `schema-failure-640.png`
