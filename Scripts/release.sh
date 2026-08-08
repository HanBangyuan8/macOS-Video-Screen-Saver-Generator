#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="${VIDEO_SCREEN_SAVER_VERSION:-1.0.2}"
BUILD_VERSION="${VIDEO_SCREEN_SAVER_BUILD_VERSION:-3}"
DIST_DIR="$ROOT_DIR/dist"
RELEASE_STAGE_DIR="$(mktemp -d "${TMPDIR:-/tmp}/video-screen-saver-generator-release.XXXXXX")"
BUILD_OUTPUT="$RELEASE_STAGE_DIR/verified-build"
APP_PATH=""
ZIP_PATH=""
DMG_PATH=""
MOUNT_POINT=""
UI_QA_STATUS="${VIDEO_SCREEN_SAVER_UI_QA_STATUS:-not-run}"

case "$UI_QA_STATUS" in
    passed) APP_WORKFLOW_JSON=true ;;
    *) APP_WORKFLOW_JSON=false ;;
esac

cleanup() {
    if [[ -n "$MOUNT_POINT" ]] && mount | grep -Fq "on $MOUNT_POINT "; then
        hdiutil detach "$MOUNT_POINT" >/dev/null 2>&1 || true
    fi
    rm -rf "$RELEASE_STAGE_DIR"
}
trap cleanup EXIT

clean_release_bundle_metadata() {
    local bundle_path="$1"
    find "$bundle_path" -name "._*" -delete
    if command -v dot_clean >/dev/null 2>&1; then
        dot_clean -m "$bundle_path" >/dev/null 2>&1 || true
    fi
    xattr -cr "$bundle_path" >/dev/null 2>&1 || true
    while IFS= read -r -d '' item; do
        xattr -d com.apple.FinderInfo "$item" >/dev/null 2>&1 || true
        xattr -d 'com.apple.fileprovider.fpfs#P' "$item" >/dev/null 2>&1 || true
    done < <(find "$bundle_path" -print0)
}

verify_signature_after_cleanup() {
    local bundle_path="$1"
    local verify_kind="${2:-deep}"
    local attempt

    for attempt in 1 2 3 4 5; do
        clean_release_bundle_metadata "$bundle_path"
        if [[ "$verify_kind" == "deep" ]]; then
            if codesign --verify --deep --strict "$bundle_path" >/dev/null 2>&1; then
                return 0
            fi
        elif codesign --verify --strict "$bundle_path" >/dev/null 2>&1; then
            return 0
        fi
        sleep 1
    done

    echo "Signature verification failed after metadata cleanup retries: $bundle_path" >&2
    clean_release_bundle_metadata "$bundle_path"
    if [[ "$verify_kind" == "deep" ]]; then
        codesign --verify --deep --strict "$bundle_path"
    else
        codesign --verify --strict "$bundle_path"
    fi
}

if [[ "$(uname -s)" != "Darwin" ]]; then
    echo "Release packaging requires macOS." >&2
    exit 1
fi

mkdir -p "$DIST_DIR"
mkdir -p "$RELEASE_STAGE_DIR/clang-module-cache"
VIDEO_SCREEN_SAVER_VERSION="$VERSION" \
VIDEO_SCREEN_SAVER_BUILD_VERSION="$BUILD_VERSION" \
CLANG_MODULE_CACHE_PATH="$RELEASE_STAGE_DIR/clang-module-cache" \
SWIFTPM_MODULECACHE_OVERRIDE="$RELEASE_STAGE_DIR/clang-module-cache" \
    swift "$ROOT_DIR/Scripts/generate-app-icon.swift"

echo "== Clean build and three-pass validation =="
VIDEO_SCREEN_SAVER_VERSION="$VERSION" \
VIDEO_SCREEN_SAVER_BUILD_VERSION="$BUILD_VERSION" \
VIDEO_SAVER_BUILD_OUTPUT="$BUILD_OUTPUT" \
    "$ROOT_DIR/build.command" --no-open --non-interactive

echo "== Package Universal 2 app =="
APP_PATH="$(VIDEO_SCREEN_SAVER_VERSION="$VERSION" \
VIDEO_SCREEN_SAVER_BUILD_VERSION="$BUILD_VERSION" \
VIDEO_SAVER_BUILT_APP_PATH="$BUILD_OUTPUT/Video Screen Saver Generator.app" \
    "$ROOT_DIR/Scripts/package-app.sh" release | tail -n 1)"

echo "== Package ZIP and compressed UDZO DMG =="
PACKAGE_OUTPUT="$(VIDEO_SAVER_APP_PATH="$APP_PATH" "$ROOT_DIR/Scripts/package-dmg.sh" release)"
ZIP_PATH="$(printf '%s\n' "$PACKAGE_OUTPUT" | sed -n '1p')"
DMG_PATH="$(printf '%s\n' "$PACKAGE_OUTPUT" | sed -n '2p')"

echo "== Verify architecture and signatures =="
"$ROOT_DIR/Scripts/check-architecture.sh" "$APP_PATH"
verify_signature_after_cleanup "$APP_PATH" deep
verify_signature_after_cleanup "$APP_PATH/Contents/Resources/VideoScreenSaver.saver" strict

echo "== Verify ZIP extraction =="
ZIP_CHECK_DIR="$RELEASE_STAGE_DIR/zip-check"
mkdir -p "$ZIP_CHECK_DIR"
ditto -x -k --norsrc "$ZIP_PATH" "$ZIP_CHECK_DIR"
ZIP_EXTRACTED_APP="$ZIP_CHECK_DIR/Video Screen Saver Generator.app"
[[ -d "$ZIP_EXTRACTED_APP" ]] || { echo "ZIP does not contain the clean app bundle." >&2; exit 1; }
codesign --verify --deep --strict "$ZIP_EXTRACTED_APP"

echo "== Verify DMG root topology =="
MOUNT_POINT="$RELEASE_STAGE_DIR/dmg-mount"
mkdir -p "$MOUNT_POINT"
hdiutil attach "$DMG_PATH" -nobrowse -noautoopen -readonly -mountpoint "$MOUNT_POINT" >/dev/null
[[ -d "$MOUNT_POINT/Video Screen Saver Generator.app" ]] || { echo "DMG app is missing." >&2; exit 1; }
[[ -L "$MOUNT_POINT/Applications" ]] || { echo "DMG Applications link is missing." >&2; exit 1; }
[[ "$(readlink "$MOUNT_POINT/Applications")" == "/Applications" ]] || { echo "DMG Applications link is incorrect." >&2; exit 1; }
TOP_LEVEL_COUNT="$(find "$MOUNT_POINT" -mindepth 1 -maxdepth 1 -print | wc -l | tr -d ' ')"
[[ "$TOP_LEVEL_COUNT" == "2" ]] || { echo "DMG contains unexpected top-level items." >&2; exit 1; }
codesign --verify --deep --strict "$MOUNT_POINT/Video Screen Saver Generator.app"
hdiutil detach "$MOUNT_POINT" >/dev/null
MOUNT_POINT=""

# Verification can re-materialize Finder metadata on a destination under a
# quarantined workspace. Leave the final dist app clean after all verification.
clean_release_bundle_metadata "$APP_PATH"

echo "== Generate release checksums =="
APP_BASENAME="$(basename "$APP_PATH")"
SOURCE_ARCHIVE="$DIST_DIR/macOS-Video-Screen-Saver-Generator-v${VERSION}-source.zip"
rm -f "$ZIP_PATH.sha256" "$DMG_PATH.sha256" "$SOURCE_ARCHIVE" "$SOURCE_ARCHIVE.sha256"
shasum -a 256 "$ZIP_PATH" > "$ZIP_PATH.sha256"
shasum -a 256 "$DMG_PATH" > "$DMG_PATH.sha256"

echo "== Create source archive =="
(
    cd "$ROOT_DIR"
    zip -q -r "$SOURCE_ARCHIVE" . \
        -x '.git/*' '*/.git/*' \
        -x '.build/*' '*/.build/*' \
        -x '.swiftpm/*' '*/.swiftpm/*' \
        -x '.venv/*' '*/.venv/*' \
        -x '.pytest_cache/*' '*/.pytest_cache/*' \
        -x 'dist/*' '*/dist/*' \
        -x 'Resources/AppIcon.iconset/*' 'Resources/AppIcon.iconset' \
        -x '.DS_Store' '*/.DS_Store' \
        -x '*.log' '*/Logs/*' '*/Cache/*'
)
shasum -a 256 "$SOURCE_ARCHIVE" > "$SOURCE_ARCHIVE.sha256"

APP_HASH="$(shasum -a 256 "$ZIP_PATH" | awk '{print $1}')"
DMG_HASH="$(shasum -a 256 "$DMG_PATH" | awk '{print $1}')"
SOURCE_HASH="$(shasum -a 256 "$SOURCE_ARCHIVE" | awk '{print $1}')"
APP_ARCHS="$(lipo -archs "$APP_PATH/Contents/MacOS/VideoScreenSaverGenerator")"
SAVER_ARCHS="$(lipo -archs "$APP_PATH/Contents/Resources/VideoScreenSaver.saver/Contents/MacOS/VideoScreenSaver")"

cat > "$DIST_DIR/release-manifest.json" <<EOF
{
  "productName": "Video Screen Saver Generator",
  "repositoryName": "macOS-Video-Screen-Saver-Generator",
  "appVersion": "$VERSION",
  "buildVersion": "$BUILD_VERSION",
  "platform": "macOS",
  "architectures": {
    "app": "$APP_ARCHS",
    "screenSaver": "$SAVER_ARCHS"
  },
  "appArtifact": "$APP_BASENAME",
  "zipArtifact": "$(basename "$ZIP_PATH")",
  "dmgArtifact": "$(basename "$DMG_PATH")",
  "sourceArtifact": "$(basename "$SOURCE_ARCHIVE")",
  "sha256": {
    "zip": "$APP_HASH",
    "dmg": "$DMG_HASH",
    "source": "$SOURCE_HASH"
  },
  "signed": false,
  "signing": "ad-hoc",
  "notarized": false,
  "validation": {
    "pass1": true,
    "pass2": true,
    "pass3": true,
    "appWorkflow": $APP_WORKFLOW_JSON,
    "uiWorkflowQA": "$UI_QA_STATUS"
  }
}
EOF

echo "Release artifacts: $DIST_DIR"
find "$DIST_DIR" -maxdepth 1 -type f -name "macOS-Video-Screen-Saver-Generator-v${VERSION}-*" -print | sort
