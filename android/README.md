# Memoria Android

Native Android app for the Memoria friend memory command center.

This app uses local SQLiteOpenHelper data storage and Android Keystore encrypted preferences for the user's DeepSeek API key. See `../docs/native-companion-scope.md`.

## What is included

- Native Java Android app without Jetpack Compose, AndroidX, or runtime third-party dependencies.
- Responsive layout:
  - wide screens use a Quiet Premium dark-green sidebar;
  - phone screens use a bottom horizontal navigation rail.
- SQLite seed/load for people, AI Inbox, reminders, gifts, and quick captures.
- AI Inbox confirm/discard behavior.
- People group filters.
- Quick Capture that writes a local memory and creates a pending update instead of mutating profiles directly.
- DeepSeek Flash/Pro, deep thinking, API key save/test/remove, and language settings.
- Search results with source citations.
- File/import progress and relationship map visualization.

## Toolchain

This project is configured for:

- Android Gradle Plugin `9.2.1`
- Gradle `9.4.1+`
- Java source/target compatibility `17`
- `compileSdk 37`, `targetSdk 37`, `minSdk 26`

Current workspace limitation: Gradle can start from `android/gradlew`, but Maven dependency downloads may be blocked by upstream 403 responses on this network. Android Studio or a network with Maven access is needed for a full assemble pass.

## Run

After installing Android Studio:

1. Open the `android/` folder in Android Studio.
2. Let Gradle sync.
3. Run the `app` configuration on an emulator or device.

From this repository root, after the Android SDK is available:

```bash
./script/build_android.sh assemble
./script/build_android.sh install
```

The project includes `android/gradlew`, a small project-local Gradle launcher that downloads Gradle `9.5.1` into `android/.gradle-wrapper` on first use. This avoids requiring a global Gradle installation. Android Studio's native Gradle sync also works.

If using a local SDK path instead of environment variables, create `android/local.properties`:

```properties
sdk.dir=/Users/YOUR_NAME/Library/Android/sdk
```

## Local AI boundary

The API key is encrypted with an Android Keystore AES/GCM key before being stored in app preferences. The key is not written to SQLite, logs, docs, or source. DeepSeek extraction results go to AI Inbox / 待确认 first.
