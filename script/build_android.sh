#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-assemble}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ANDROID_DIR="$ROOT_DIR/android"

cd "$ANDROID_DIR"

if [[ -z "${ANDROID_HOME:-}" && -z "${ANDROID_SDK_ROOT:-}" && ! -f local.properties ]]; then
  cat >&2 <<'EOF'
Android SDK not found.

Install Android Studio or Android command-line tools, then set ANDROID_HOME or
create android/local.properties with:

sdk.dir=/absolute/path/to/Android/sdk
EOF
  exit 3
fi

if [[ -x ./gradlew ]]; then
  GRADLE_CMD=(./gradlew)
elif command -v gradle >/dev/null 2>&1; then
  GRADLE_CMD=(gradle)
else
  cat >&2 <<'EOF'
Gradle not found.

Open android/ in Android Studio and let it sync the project, or install/use a
project Gradle wrapper before running this script.
EOF
  exit 4
fi

case "$MODE" in
  assemble|--assemble)
    "${GRADLE_CMD[@]}" :app:assembleDebug
    ;;
  install|--install)
    "${GRADLE_CMD[@]}" :app:installDebug
    ;;
  test|--test)
    "${GRADLE_CMD[@]}" :app:testDebugUnitTest
    ;;
  lint|--lint)
    "${GRADLE_CMD[@]}" :app:lintDebug
    ;;
  *)
    echo "usage: $0 [assemble|install|test|lint]" >&2
    exit 2
    ;;
esac
