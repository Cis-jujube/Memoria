# Memoria AI Contract

AI workflows are workflow-first and side-effect free. A model may classify,
extract, summarize, and propose, but it must not mutate confirmed records.

## Provider

- Base URL: `https://api.deepseek.com`
- Fast model: `deepseek-v4-flash`
- Pro model: `deepseek-v4-pro`
- API key storage: macOS Keychain only

## JSON Requirement

Structured calls must request JSON object output and prompts must include an
explicit JSON example. The app validates model output before writing
`PendingUpdate` rows.

Current baseline is `extract_memory v1.0`: responses without `schema_version`
and `contract_name` remain readable for existing fixtures and saved outputs.
The enhanced contract is `extract_memory v1.1`: responses must include
`schema_version: "1.1"` and `contract_name: "extract_memory"`. Unknown
versions or wrong contract names fail closed: the `RawEntry` remains saved, no
confirmed facts are written, and the app can fall back to local extraction.

This phase does not change provider, database schema, or the review workflow:
DeepSeek remains the native provider, SQLite keeps the same tables, and every
model proposal still goes through `RawEntry -> PendingUpdate -> 整理台 -> user
approval -> MemoryAtom`.

## route_input

Input: raw user text.

Output shape:

```json
{
  "primary_type": "personal_reflection",
  "secondary_types": ["relationship_memory"],
  "confidence": 0.86,
  "requires_extraction": true,
  "requires_person_linking": true,
  "requires_reminder_generation": false,
  "requires_gift_generation": false,
  "language": "zh",
  "reason_summary": "User is reflecting on a relationship."
}
```

## extract_memory

Input includes `raw_entry_id`, `raw_text`, known people, and known themes.

Output must include:

- `schema_version` and `contract_name` for v1.1 output
- `entry_summary`
- `memory_proposals`
- `person_fact_proposals`
- `reminder_proposals`
- `gift_signal_proposals`
- `conflicts`
- `follow_up_questions`

Each memory proposal must include `source_quote`, confidence, sensitivity,
whether it is AI-inferred, related people, and themes.

Person/profile facts must use one `profile_category` key from this shared
schema. This is the foundation for both SQLite `category_notes_json` and AI
classification:

| Category key | Category |
| --- | --- |
| `identity` | 身份信息 |
| `contact` | 联系方式 |
| `relationship` | 关系信息 |
| `education` | 教育经历 |
| `career` | 职业经历 |
| `family` | 家庭关系 |
| `friend_network` | 朋友网络 |
| `interests` | 兴趣爱好 |
| `media` | 书影音 |
| `food_preference` | 饮食偏好 |
| `dietary_allergy` | 忌口过敏 |
| `travel_preference` | 旅行偏好 |
| `style_aesthetic` | 穿搭审美 |
| `spending_preference` | 消费偏好 |
| `gift_history` | 礼物历史 |
| `lifestyle` | 生活习惯 |
| `current_state` | 当前状态 |
| `life_events` | 人生大事 |
| `emotional_preference` | 情绪偏好 |
| `communication_preference` | 沟通偏好 |
| `taboo_boundary` | 禁区边界 |
| `anniversaries` | 纪念日 |
| `reminders` | 提醒事项 |
| `files` | 文件资料 |
| `ai_inference` | AI 推断 |

AI-inferred style, gift, or relationship-change guesses must be placed under
`ai_inference` and marked as inferred. They must not be stored as confirmed
facts unless the user approves them.

`reminder_proposals` and `gift_signal_proposals` may use the v1.1 structured
objects. The native app projects them into reviewable `MemoryAtomProposal`
records with a compatible `pending_update_payload` envelope. They do not write
`reminders` or `gift_ideas` directly.

Structured `reminder_proposals` also carry the classification-boundary fields
used by 整理台 review: `classification.proposition_units`, separated
`semantic_primary_unit_id` / `workflow_primary_unit_id`, `workflow_primary`,
`secondary_workflows`, `storage_targets`, `schedule_subtype`,
`schedule_execution_state`, `time_role`, `time_expression_kind`,
`time_precision`, `commitment_level`, `notification_policy`,
`needs_slot_confirmation`, `confirmation_blockers`, and
`requires_user_approval`. A proposal may be reviewable while still blocked from
becoming an executable reminder; `requires_user_approval` must remain `true`.

`value_struct` is allowed only for the current minimum high-value profile
categories: `anniversaries`, `dietary_allergy`, and `contact`. It supplements
the human-readable `proposed_value`; it does not replace it.

Generation and canonical schema anchors live at:

- `docs/schemas/extract-memory.generation.v1.1.schema.json`
- `docs/schemas/extract-memory.canonical.v1.1.schema.json`

Gift recommendations must expose reason, risk, confirmation question, match
score, surprise score, risk level, practicality, emotional value, and whether
more information is needed.

## Failure Handling

The UI must make these states clear:

- missing API key
- network failure
- invalid key or 401
- rate limit
- timeout
- empty response
- invalid JSON
- schema validation failure

In all cases, `RawEntry` remains saved locally.

## Connection Test

Settings `Test connection` must not run the full `extract_memory` workflow. It
uses a minimal chat completion JSON ping:

```json
{"ok": true, "service": "deepseek"}
```

This verifies that the API key, selected model, network path, and JSON-object
mode are usable. A successful connection test does not guarantee that a later
long extraction prompt will pass schema validation; extraction failures are
reported separately and the saved `RawEntry` remains local.
