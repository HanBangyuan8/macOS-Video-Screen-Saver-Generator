#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_PATH="${1:-}"
if [[ -z "$APP_PATH" ]]; then
    APP_PATH="$(find "$ROOT_DIR/dist" -maxdepth 1 -type d -name '*.app' -print | sort | tail -n 1)"
fi
[[ -d "$APP_PATH" ]] || { echo "App bundle not found: $APP_PATH" >&2; exit 1; }

APP_BINARY="$APP_PATH/Contents/MacOS/VideoScreenSaverGenerator"
SAVER_BINARY="$APP_PATH/Contents/Resources/VideoScreenSaver.saver/Contents/MacOS/VideoScreenSaver"
[[ -f "$APP_BINARY" && -f "$SAVER_BINARY" ]] || { echo "Expected app or saver binary is missing." >&2; exit 1; }

APP_ARCHS="$(lipo -archs "$APP_BINARY")"
SAVER_ARCHS="$(lipo -archs "$SAVER_BINARY")"
[[ "$APP_ARCHS" == *arm64* && "$APP_ARCHS" == *x86_64* ]] || { echo "App architectures: $APP_ARCHS" >&2; exit 1; }
[[ "$SAVER_ARCHS" == *arm64* && "$SAVER_ARCHS" == *x86_64* ]] || { echo "Saver architectures: $SAVER_ARCHS" >&2; exit 1; }

echo "App: $APP_ARCHS"
echo "Saver: $SAVER_ARCHS"
echo "Universal 2 architecture check passed."
