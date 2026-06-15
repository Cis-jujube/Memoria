# DeepSeek API Interface

Memoria now has two DeepSeek integration boundaries:

- Native local apps call DeepSeek directly with the user's own API key saved in platform secure storage.
- The web app remains a visual/API reference and may still use server-side environment variables for its existing routes.

Do not hard-code API keys in source, docs, fixtures, logs, or snapshots. Any key pasted into chat should be treated as exposed and rotated.

## Web Reference Environment

```bash
AI_PROVIDER="deepseek"
DEEPSEEK_API_KEY="..."
DEEPSEEK_MODEL="deepseek-v4-flash"
DEEPSEEK_BASE_URL="https://api.deepseek.com"
AI_MOCK_FALLBACK="false"
```

`DEEPSEEK_BASE_URL` defaults to `https://api.deepseek.com`.

Native apps do not read `DEEPSEEK_API_KEY` from `.env`. The user enters a key in Settings.

## Web Backend Interface

### `POST /api/ai/extract`

Authenticated route. Extracts structured friend-memory JSON and does not write to the database.

Request:

```json
{
  "text": "Yesterday Alex said he has a calculus midterm on 5/20 and does not eat cilantro.",
  "locale": "zh-CN/en-US",
  "timezone": "Asia/Shanghai"
}
```

Response:

```json
{
  "provider": "deepseek",
  "writesDatabase": false,
  "extraction": {
    "people": [],
    "reminders": [],
    "giftIdeas": []
  }
}
```

### `POST /api/capture`

Authenticated route. Creates a `Memory`, calls the selected AI provider, normalizes the extraction, and writes `PendingUpdate` rows. Profile data is not mutated until the user confirms pending updates.

## DeepSeek Upstream Contract

The web server uses the OpenAI SDK with:

- `baseURL: "https://api.deepseek.com"`
- `model: process.env.DEEPSEEK_MODEL || "deepseek-v4-flash"`
- `chat.completions.create(...)`
- `response_format: { type: "json_object" }`

The model prompt explicitly asks for JSON, then the server validates with `extractionPayloadSchema` before returning or writing anything.

## Native App Contract

Native clients use the same DeepSeek upstream shape:

- `POST https://api.deepseek.com/chat/completions`
- `model: "deepseek-v4-flash"` or `"deepseek-v4-pro"`
- `response_format: { "type": "json_object" }`
- thinking off: `thinking: { "type": "disabled" }`
- thinking on: `thinking: { "type": "enabled" }` and `reasoning_effort: "high"`

Settings connection tests use a minimal JSON ping through `/chat/completions`.
They do not run the full Memoria extraction schema, so a connectivity/model
failure is not confused with a business JSON validation failure.

Native storage boundaries:

- iOS/macOS: SQLite3 for app data, Keychain for the API key.
- Android: SQLiteOpenHelper for app data, Android Keystore encrypted preferences for the API key.
- Windows: rusqlite for app data, OS keyring / Windows Credential Manager for the API key.

## Security Boundary

- Do not expose `DEEPSEEK_API_KEY` through `NEXT_PUBLIC_`.
- Do not put native API keys in SQLite.
- Do not write extraction results directly to profiles. Use pending updates with source evidence.
