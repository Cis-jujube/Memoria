# Native Local Scope

Product delivery is now local native first across iOS, macOS, Android, and Windows.
The web app remains useful as a visual and interaction reference, but it is not the product runtime for this round.

Native clients share these boundaries:

- relationship data lives in local SQLite;
- API keys never go into SQLite, source, logs, docs, or test snapshots;
- users enter their own rotated DeepSeek API key in Settings;
- AI extraction creates pending updates first;
- confirming or discarding a pending update controls when profile data changes;
- language supports System, Chinese, and English, with Chinese copy written separately.

## Platform Storage

- iOS/macOS: system SQLite3 plus Keychain.
- Android: SQLiteOpenHelper plus Android Keystore encrypted preferences.
- Windows: Tauri/Rust with rusqlite plus OS keyring / Windows Credential Manager.

## Out of Scope For This Round

- account system and cloud sync;
- Vercel/Neon/SendGrid/Google OAuth as product dependencies;
- file OCR, PDF parsing, and cross-device merge conflicts;
- final Windows `.msi` / `.exe` signing and packaging verification on macOS.
