#!/usr/bin/env bash
set -euo pipefail

PRODUCT_NAME="Video Screen Saver Generator"
EXECUTABLE_NAME="VideoScreenSaverGenerator"
BUNDLE_IDENTIFIER="com.han.VideoScreenSaverGenerator"
VERSION="${VIDEO_SCREEN_SAVER_VERSION:-1.0.5}"
BUILD_VERSION="${VIDEO_SCREEN_SAVER_BUILD_VERSION:-6}"
CONFIGURATION="${1:-release}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
STAGE_DIR="$(mktemp -d "${TMPDIR:-/tmp}/video-screen-saver-generator-package.XXXXXX")"
APP_DIR="$STAGE_DIR/$PRODUCT_NAME.app"
FINAL_APP_DIR="$DIST_DIR/macOS-Video-Screen-Saver-Generator-v${VERSION}-macOS-universal.app"

trap 'rm -rf "$STAGE_DIR"' EXIT

clean_bundle_metadata() {
    local bundle_path="$1"
    find "$bundle_path" -name "._*" -delete
    if command -v dot_clean >/dev/null 2>&1; then
        dot_clean -m "$bundle_path"
    fi
    if command -v xattr >/dev/null 2>&1; then
        xattr -cr "$bundle_path" 2>/dev/null || true
        while IFS= read -r -d '' item; do
            xattr -d com.apple.FinderInfo "$item" 2>/dev/null || true
            xattr -d 'com.apple.fileprovider.fpfs#P' "$item" 2>/dev/null || true
        done < <(find "$bundle_path" -print0)
    fi
}

sign_bundle_with_retries() {
    local bundle_path="$1"
    local attempt
    for attempt in 1 2 3 4 5; do
        clean_bundle_metadata "$bundle_path"
        if codesign --force --deep --sign - --timestamp=none "$bundle_path" >/dev/null 2>&1; then
            clean_bundle_metadata "$bundle_path"
            if codesign --verify --deep --strict "$bundle_path" >/dev/null 2>&1; then
                return 0
            fi
        fi
        sleep 1
    done

    clean_bundle_metadata "$bundle_path"
    codesign --force --deep --sign - --timestamp=none "$bundle_path"
    clean_bundle_metadata "$bundle_path"
    codesign --verify --deep --strict "$bundle_path"
}

verify_bundle_with_retries() {
    local bundle_path="$1"
    local attempt
    for attempt in 1 2 3 4 5; do
        clean_bundle_metadata "$bundle_path"
        if codesign --verify --deep --strict "$bundle_path" >/dev/null 2>&1; then
            return 0
        fi
        sleep 1
    done

    clean_bundle_metadata "$bundle_path"
    codesign --verify --deep --strict "$bundle_path"
}

assert_no_user_cache_payload() {
    local bundle_path="$1"
    if find "$bundle_path" \( \
        -name "*.sqlite" -o -name "*.sqlite-*" -o -name "*Cache*" -o -name "*cache*" \
        -o -name "*.mp4" -o -name "*.mov" -o -name "*.m4v" -o -name "video.*" \
    \) -print -quit | grep -q .; then
        echo "Refusing to package user media, generated state, or cache inside $bundle_path" >&2
        exit 1
    fi
}

if [[ "$(uname -s)" != "Darwin" ]]; then
    echo "This package flow requires macOS." >&2
    exit 1
fi

BUILT_APP="${VIDEO_SAVER_BUILT_APP_PATH:-}"
if [[ -z "$BUILT_APP" ]]; then
    BUILD_OUTPUT="$STAGE_DIR/verified-build"
    VIDEO_SCREEN_SAVER_VERSION="$VERSION" \
    VIDEO_SCREEN_SAVER_BUILD_VERSION="$BUILD_VERSION" \
    VIDEO_SAVER_BUILD_OUTPUT="$BUILD_OUTPUT" \
        "$ROOT_DIR/build.command" --no-open --non-interactive
    BUILT_APP="$BUILD_OUTPUT/$PRODUCT_NAME.app"
fi

if [[ ! -d "$BUILT_APP" ]]; then
    echo "Verified app not found: $BUILT_APP" >&2
    exit 1
fi
if [[ ! -f "$ROOT_DIR/Resources/AppIcon.icns" ]]; then
    echo "Missing Resources/AppIcon.icns. Run Scripts/generate-app-icon.swift first." >&2
    exit 1
fi

ditto --norsrc "$BUILT_APP" "$APP_DIR"
plutil -replace CFBundleDisplayName -string "$PRODUCT_NAME" "$APP_DIR/Contents/Info.plist"
plutil -replace CFBundleExecutable -string "$EXECUTABLE_NAME" "$APP_DIR/Contents/Info.plist"
plutil -replace CFBundleIdentifier -string "$BUNDLE_IDENTIFIER" "$APP_DIR/Contents/Info.plist"
plutil -replace CFBundleName -string "$PRODUCT_NAME" "$APP_DIR/Contents/Info.plist"
plutil -replace CFBundleShortVersionString -string "$VERSION" "$APP_DIR/Contents/Info.plist"
plutil -replace CFBundleVersion -string "$BUILD_VERSION" "$APP_DIR/Contents/Info.plist"
plutil -replace CFBundleIconFile -string "AppIcon" "$APP_DIR/Contents/Info.plist"

SAVER_PATH="$APP_DIR/Contents/Resources/VideoScreenSaver.saver"
[[ -d "$SAVER_PATH" ]] || { echo "Embedded VideoScreenSaver.saver is missing." >&2; exit 1; }
[[ -x "$APP_DIR/Contents/MacOS/$EXECUTABLE_NAME" ]] || { echo "App executable is missing." >&2; exit 1; }
[[ -f "$APP_DIR/Contents/Resources/AppIcon.icns" ]] || cp "$ROOT_DIR/Resources/AppIcon.icns" "$APP_DIR/Contents/Resources/AppIcon.icns"

clean_bundle_metadata "$APP_DIR"
assert_no_user_cache_payload "$APP_DIR"
sign_bundle_with_retries "$APP_DIR"
assert_no_user_cache_payload "$APP_DIR"
verify_bundle_with_retries "$APP_DIR"

APP_ARCHS="$(lipo -archs "$APP_DIR/Contents/MacOS/$EXECUTABLE_NAME")"
SAVER_ARCHS="$(lipo -archs "$SAVER_PATH/Contents/MacOS/VideoScreenSaver")"
[[ "$APP_ARCHS" == *arm64* && "$APP_ARCHS" == *x86_64* ]] || { echo "App is not Universal 2: $APP_ARCHS" >&2; exit 1; }
[[ "$SAVER_ARCHS" == *arm64* && "$SAVER_ARCHS" == *x86_64* ]] || { echo "Saver is not Universal 2: $SAVER_ARCHS" >&2; exit 1; }
codesign --verify --strict "$SAVER_PATH"

mkdir -p "$DIST_DIR"
rm -rf "$FINAL_APP_DIR"
ditto --norsrc "$APP_DIR" "$FINAL_APP_DIR"
clean_bundle_metadata "$FINAL_APP_DIR"
assert_no_user_cache_payload "$FINAL_APP_DIR"
sign_bundle_with_retries "$FINAL_APP_DIR"
verify_bundle_with_retries "$FINAL_APP_DIR"

echo "$FINAL_APP_DIR"
