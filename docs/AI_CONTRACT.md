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
