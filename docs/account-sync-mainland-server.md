# Memoria Account Sync For A Mainland China Server

## Product Direction

Memoria can support free accounts and cross-device sync while keeping DeepSeek API keys device-local.
The account only syncs relationship data: people, memories, pending updates, reminders, gift ideas, files metadata, and relationship edges.
Users still bring their own DeepSeek API key on each device.

## Recommended V1 Architecture

- Web + API: Next.js app deployed to the user's mainland China server.
- Database: Postgres on the same server or a managed mainland-compatible Postgres instance.
- Auth: email/password or email magic link first; Google OAuth should stay optional because mainland reliability is uneven.
- Native apps: iOS, macOS, Android, and Windows call the sync API over HTTPS.
- Local-first behavior: each app keeps SQLite as the working store, then pushes/pulls changes when signed in.
- Secrets: server owns auth/session secrets; native devices own DeepSeek keys in Keychain, Keystore, or Credential Manager.

## Free Registration

V1 can be free:

- email + password signup;
- email verification if SMTP is available;
- no paid plan gates;
- per-account rate limits for sync and upload metadata;
- DeepSeek API usage billed to the user's own key, not the server.

## Sync Data Model

Each synced row should carry:

- `id`: stable UUID generated client-side when offline.
- `userId`: server owner.
- `updatedAt`: server-side canonical update timestamp.
- `deletedAt`: nullable tombstone for cross-device deletes.
- `deviceId`: local install identifier.
- `syncVersion`: monotonically increasing integer or server revision.

Tables to sync:

- `people`
- `memories`
- `pending_updates`
- `reminders`
- `gift_ideas`
- `relationship_edges`
- `uploaded_files` metadata only in V1
- `audit_events`

Do not sync:

- DeepSeek API keys;
- raw OS credential-store values;
- local debug logs;
- unconfirmed OCR/PDF raw blobs in V1.

## API Surface

```http
POST /api/auth/register
POST /api/auth/login
POST /api/auth/logout
GET  /api/sync/pull?since=<cursor>
POST /api/sync/push
POST /api/sync/ack
```

`POST /api/sync/push` request:

```json
{
  "deviceId": "mac-uuid",
  "baseCursor": "server-cursor",
  "changes": {
    "people": [],
    "memories": [],
    "pendingUpdates": [],
    "reminders": [],
    "giftIdeas": []
  }
}
```

`GET /api/sync/pull` response:

```json
{
  "cursor": "next-server-cursor",
  "serverTime": "2026-06-11T00:00:00.000Z",
  "changes": {
    "people": [],
    "memories": [],
    "pendingUpdates": [],
    "reminders": [],
    "giftIdeas": []
  }
}
```

## Conflict Policy

Use simple, explainable rules for V1:

- text/profile fields: latest confirmed update wins, but keep an audit event;
- reminders: latest `updatedAt` wins unless one side is deleted, then tombstone wins;
- pending updates: review state wins over content edits;
- memories: append-only except delete/tombstone;
- gift ideas: latest update wins.

If a conflict cannot be merged, keep both values and create a pending update titled `需要确认的同步冲突`.

## Native Settings UX

Add an Account & Sync section to each app:

- signed out: server URL, email, password, create account, sign in;
- signed in: email, last synced time, sync now, sign out;
- clear statement: DeepSeek API key stays on this device and is not uploaded.

Chinese copy direction:

- `账号与同步`
- `登录后，手机和电脑上的联系人、记忆、提醒会同步。DeepSeek API key 仍然只保存在这台设备。`
- `立即同步`
- `退出登录`

## Deployment Notes

For a mainland China server:

- use HTTPS with a real domain before native sync;
- keep database backups on;
- store server secrets in environment variables;
- enable firewall rules for SSH/HTTP/HTTPS only;
- avoid depending on Google login as the only auth route;
- add request body limits and per-account rate limits before file sync.
