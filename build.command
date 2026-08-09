#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")"
ROOT="$(pwd)"
BUILD="${VIDEO_SAVER_BUILD_DIR:-}"
OUT="${VIDEO_SAVER_BUILD_OUTPUT:-$HOME/Desktop/Video Screen Saver Generator Build}"
REPORT="$OUT/Verification Report.txt"
MIN_VERSION="15.0"
APP_VERSION="${VIDEO_SCREEN_SAVER_VERSION:-1.0.4}"
BUILD_VERSION="${VIDEO_SCREEN_SAVER_BUILD_VERSION:-5}"
NO_OPEN=0
NON_INTERACTIVE=0

BUILD_CREATED_BY_SCRIPT=0
if [[ -z "$BUILD" ]]; then
  BUILD="$(mktemp -d "${TMPDIR:-/tmp}/video-screen-saver-generator-build.XXXXXX")"
  BUILD_CREATED_BY_SCRIPT=1
fi

cleanup() {
  if [[ "$BUILD_CREATED_BY_SCRIPT" -eq 1 && -n "$BUILD" && -d "$BUILD" ]]; then
    rm -rf "$BUILD"
  fi
}
trap cleanup EXIT

for argument in "$@"; do
  case "$argument" in
    --no-open) NO_OPEN=1 ;;
    --non-interactive) NON_INTERACTIVE=1 ;;
    *)
      echo "Unknown argument: $argument" >&2
      exit 2
      ;;
  esac
done

function die() {
  echo "❌ $1" >&2
  exit 1
}

function need() {
  command -v "$1" >/dev/null 2>&1 || die "Missing $1. Install Xcode and launch it once to accept the license."
}

need xcrun
need codesign
need plutil
need xattr

SDK="$(xcrun --sdk macosx --show-sdk-path)"
CLANG="$(xcrun -f clang)"
SWIFTC="$(xcrun -f swiftc)"
LIPO="$(xcrun -f lipo)"
OTOOL="$(xcrun -f otool)"
NM="$(xcrun -f nm)"

APP_SOURCES=()
while IFS= read -r source_file; do
  APP_SOURCES+=("$source_file")
done < <(find "$ROOT/Sources/App" -maxdepth 1 -type f -name '*.swift' -print | sort)
[[ "${#APP_SOURCES[@]}" -gt 0 ]] || die "No Swift app sources found."

case "$OUT" in
  ""|"/"|"$ROOT") die "Refusing to use an unsafe build output directory: $OUT" ;;
esac
[[ "$OUT" != "$BUILD" ]] || die "Build output and intermediate build directories must differ."

rm -rf "$BUILD" "$OUT"
mkdir -p "$BUILD" "$OUT"
export CLANG_MODULE_CACHE_PATH="$BUILD/clang-module-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$CLANG_MODULE_CACHE_PATH"
mkdir -p "$CLANG_MODULE_CACHE_PATH"
: > "$REPORT"

function report() {
  echo "$1" | tee -a "$REPORT"
}

function clean_generated_bundle() {
  local bundle_path="$1"
  find "$bundle_path" -name '._*' -delete
  if command -v dot_clean >/dev/null 2>&1; then
    dot_clean -m "$bundle_path" >/dev/null 2>&1 || true
  fi
  xattr -cr "$bundle_path" >/dev/null 2>&1 || true
  while IFS= read -r -d '' item; do
    xattr -d com.apple.FinderInfo "$item" >/dev/null 2>&1 || true
    xattr -d 'com.apple.fileprovider.fpfs#P' "$item" >/dev/null 2>&1 || true
  done < <(find "$bundle_path" -print0)
}

report "Video Screen Saver Generator — three-pass verification"
report "Date: $(date)"
report "SDK: $SDK"
report "Version: $APP_VERSION ($BUILD_VERSION)"
report ""

# -----------------------------------------------------------------------------
# PASS 1 — source / API preflight
# -----------------------------------------------------------------------------
report "[PASS 1] Source/API preflight"

plutil -lint "$ROOT/Resources/App-Info.plist" >> "$REPORT"
plutil -lint "$ROOT/Resources/Saver-Info.plist" >> "$REPORT"
plutil -lint "$ROOT/Resources/SaverConfig.plist" >> "$REPORT"

PRINCIPAL="$(plutil -extract NSPrincipalClass raw "$ROOT/Resources/Saver-Info.plist")"
[[ "$PRINCIPAL" == "VideoScreenSaverView" ]] || die "NSPrincipalClass is not VideoScreenSaverView"

grep -q '@interface VideoScreenSaverView : ScreenSaverView' "$ROOT/Sources/ScreenSaver/VideoScreenSaverView.h" || die "Screen saver entry class is incorrect"
grep -q 'AVQueuePlayer' "$ROOT/Sources/ScreenSaver/VideoScreenSaverView.m" || die "Missing AVQueuePlayer"
grep -q 'AVPlayerLooper' "$ROOT/Sources/ScreenSaver/VideoScreenSaverView.m" || die "Missing AVPlayerLooper"
grep -q 'AVPlayerLayer' "$ROOT/Sources/ScreenSaver/VideoScreenSaverView.m" || die "Missing AVPlayerLayer"
grep -q 'com.apple.screensaver.willstop' "$ROOT/Sources/ScreenSaver/VideoScreenSaverView.m" || die "Missing legacy lifecycle guard"
grep -q 'xattr' "$ROOT/Sources/App/Exporter.swift" || die "Missing generated-bundle xattr cleanup"
grep -q 'codesign' "$ROOT/Sources/App/Exporter.swift" || die "Missing generated-bundle signing"
if find "$ROOT/Sources/ScreenSaver" -type f -name '*.swift' -print -quit | grep -q .; then
  die "Swift source was introduced into the Objective-C screen saver target"
fi

"$SWIFTC" -frontend -parse "${APP_SOURCES[@]}" >> "$REPORT" 2>&1

"$CLANG" -fobjc-arc -fblocks -fmodules -fsyntax-only \
  -isysroot "$SDK" \
  -mmacosx-version-min="$MIN_VERSION" \
  -I "$ROOT/Sources/ScreenSaver" \
  "$ROOT/Sources/ScreenSaver/VideoScreenSaverView.m" \
  >> "$REPORT" 2>&1

report "PASS 1 OK: plists, deterministic Swift parse, Objective-C SDK syntax, principal class, lifecycle and architecture invariants"
report ""

# -----------------------------------------------------------------------------
# Build universal screen saver template
# -----------------------------------------------------------------------------
SAVER="$BUILD/VideoScreenSaver.saver"
mkdir -p "$SAVER/Contents/MacOS" "$SAVER/Contents/Resources"
cp "$ROOT/Resources/Saver-Info.plist" "$SAVER/Contents/Info.plist"
cp "$ROOT/Resources/SaverConfig.plist" "$SAVER/Contents/Resources/SaverConfig.plist"

for ARCH in arm64 x86_64; do
  "$CLANG" \
    -arch "$ARCH" \
    -isysroot "$SDK" \
    -mmacosx-version-min="$MIN_VERSION" \
    -fobjc-arc -fblocks -fmodules -O2 -bundle \
    -I "$ROOT/Sources/ScreenSaver" \
    "$ROOT/Sources/ScreenSaver/VideoScreenSaverView.m" \
    -framework ScreenSaver \
    -framework AppKit \
    -framework AVFoundation \
    -framework QuartzCore \
    -o "$BUILD/VideoScreenSaver-$ARCH"
done

"$LIPO" -create \
  "$BUILD/VideoScreenSaver-arm64" \
  "$BUILD/VideoScreenSaver-x86_64" \
  -output "$SAVER/Contents/MacOS/VideoScreenSaver"
chmod +x "$SAVER/Contents/MacOS/VideoScreenSaver"
clean_generated_bundle "$SAVER"
codesign --force --sign - --timestamp=none "$SAVER" >/dev/null

# -----------------------------------------------------------------------------
# Build universal Video Screen Saver Generator app
# -----------------------------------------------------------------------------
APP="$BUILD/Video Screen Saver Generator.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$ROOT/Resources/App-Info.plist" "$APP/Contents/Info.plist"
plutil -replace CFBundleShortVersionString -string "$APP_VERSION" "$APP/Contents/Info.plist"
plutil -replace CFBundleVersion -string "$BUILD_VERSION" "$APP/Contents/Info.plist"
cp -R "$SAVER" "$APP/Contents/Resources/VideoScreenSaver.saver"
if [[ -f "$ROOT/Resources/AppIcon.icns" ]]; then
  cp "$ROOT/Resources/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
fi

for ARCH in arm64 x86_64; do
  "$SWIFTC" \
    -sdk "$SDK" \
    -target "$ARCH-apple-macos${MIN_VERSION}" \
    -parse-as-library -O \
    -swift-version 5 \
    -module-name VideoScreenSaverGenerator \
    "${APP_SOURCES[@]}" \
    -framework SwiftUI \
    -framework AppKit \
    -framework AVKit \
    -framework AVFoundation \
    -framework UniformTypeIdentifiers \
    -o "$BUILD/VideoScreenSaverGenerator-$ARCH"
done

"$LIPO" -create \
  "$BUILD/VideoScreenSaverGenerator-arm64" \
  "$BUILD/VideoScreenSaverGenerator-x86_64" \
  -output "$APP/Contents/MacOS/VideoScreenSaverGenerator"
chmod +x "$APP/Contents/MacOS/VideoScreenSaverGenerator"
clean_generated_bundle "$APP"
codesign --force --deep --sign - --timestamp=none "$APP" >/dev/null
# codesign can restore Finder metadata inherited from a quarantined workspace.
# Scrub once more at the signed-artifact boundary before strict verification.
clean_generated_bundle "$APP"

# -----------------------------------------------------------------------------
# PASS 2 — binary / bundle / signature integrity
# -----------------------------------------------------------------------------
report "[PASS 2] Built artifact integrity"

APP_ARCHS="$("$LIPO" -archs "$APP/Contents/MacOS/VideoScreenSaverGenerator")"
SAVER_ARCHS="$("$LIPO" -archs "$APP/Contents/Resources/VideoScreenSaver.saver/Contents/MacOS/VideoScreenSaver")"
[[ "$APP_ARCHS" == *arm64* && "$APP_ARCHS" == *x86_64* ]] || die "Video Screen Saver Generator.app is not Universal 2: $APP_ARCHS"
[[ "$SAVER_ARCHS" == *arm64* && "$SAVER_ARCHS" == *x86_64* ]] || die ".saver is not Universal 2: $SAVER_ARCHS"

codesign --verify --deep --strict --verbose=2 "$APP" >> "$REPORT" 2>&1
codesign --verify --strict --verbose=2 "$APP/Contents/Resources/VideoScreenSaver.saver" >> "$REPORT" 2>&1

"$OTOOL" -L "$APP/Contents/Resources/VideoScreenSaver.saver/Contents/MacOS/VideoScreenSaver" >> "$REPORT"
"$NM" -gU "$APP/Contents/Resources/VideoScreenSaver.saver/Contents/MacOS/VideoScreenSaver" \
  | grep 'OBJC_CLASS_.*VideoScreenSaverView' >> "$REPORT" \
  || die "The screen saver binary does not export VideoScreenSaverView"

EMBEDDED_PRINCIPAL="$(plutil -extract NSPrincipalClass raw "$APP/Contents/Resources/VideoScreenSaver.saver/Contents/Info.plist")"
[[ "$EMBEDDED_PRINCIPAL" == "VideoScreenSaverView" ]] || die "Embedded template principal class is incorrect"
APP_EXECUTABLE="$(plutil -extract CFBundleExecutable raw "$APP/Contents/Info.plist")"
[[ "$APP_EXECUTABLE" == "VideoScreenSaverGenerator" ]] || die "App executable metadata is incorrect"

report "App architectures: $APP_ARCHS"
report "Saver architectures: $SAVER_ARCHS"
report "PASS 2 OK: Universal 2, bundle structure, exported Objective-C class, linked frameworks, signatures"
report ""

# -----------------------------------------------------------------------------
# PASS 3 — runtime smoke test on a generated saver (not just the empty template)
# -----------------------------------------------------------------------------
report "[PASS 3] Runtime smoke test"

SMOKE_DIR="$(mktemp -d "${TMPDIR:-/tmp}/video-screen-saver-generator-smoke.XXXXXX")"
SMOKE_SAVER="$SMOKE_DIR/SmokeGenerated.saver"
mkdir -p "$SMOKE_DIR"
cp -R "$SAVER" "$SMOKE_SAVER"
cp "$ROOT/TestAssets/smoke.mp4" "$SMOKE_SAVER/Contents/Resources/video.mp4"
plutil -replace CFBundleIdentifier -string local.videoscreensavergenerator.smoketest "$SMOKE_SAVER/Contents/Info.plist"
plutil -replace CFBundleName -string "Video Screen Saver Smoke Test" "$SMOKE_SAVER/Contents/Info.plist"
clean_generated_bundle "$SMOKE_SAVER"

# Regression test for signing failures caused by user-video extended attributes.
xattr -w com.videoscreensavergenerator.signing-regression "present" "$SMOKE_SAVER/Contents/Resources/video.mp4"
xattr "$SMOKE_SAVER/Contents/Resources/video.mp4" | grep -q com.videoscreensavergenerator.signing-regression \
  || die "Unable to establish the extended-attribute regression test"
xattr -c -r "$SMOKE_SAVER"
while IFS= read -r -d '' item; do
  xattr -d com.apple.FinderInfo "$item" >/dev/null 2>&1 || true
  xattr -d 'com.apple.fileprovider.fpfs#P' "$item" >/dev/null 2>&1 || true
done < <(find "$SMOKE_SAVER" -print0)
if xattr -r "$SMOKE_SAVER" | grep -q com.videoscreensavergenerator.signing-regression; then
  die "Extended-attribute cleanup regression test failed"
fi

codesign --remove-signature "$SMOKE_SAVER" >/dev/null 2>&1 || true
codesign --force --sign - --timestamp=none "$SMOKE_SAVER" >/dev/null
codesign --verify --strict "$SMOKE_SAVER"

NATIVE_ARCH="$(uname -m)"
"$CLANG" \
  -arch "$NATIVE_ARCH" \
  -isysroot "$SDK" \
  -mmacosx-version-min="$MIN_VERSION" \
  -fobjc-arc -fmodules \
  "$ROOT/Sources/SmokeTest/SaverSmokeTest.m" \
  -framework AppKit \
  -framework ScreenSaver \
  -o "$SMOKE_DIR/SaverSmokeTest"

"$SMOKE_DIR/SaverSmokeTest" "$SMOKE_SAVER" >> "$REPORT" 2>&1
report "PASS 3 OK: xattr signing regression passed; generated saver loaded via NSBundle; preview/full start-stop completed"
report ""

# Final delivery
rm -rf "$OUT/Video Screen Saver Generator.app"
ditto --norsrc "$APP" "$OUT/Video Screen Saver Generator.app"
cp "$ROOT/diagnose.command" "$OUT/diagnose.command"
chmod +x "$OUT/diagnose.command"

report "ALL THREE PASSES PASSED"
report "Output: $OUT/Video Screen Saver Generator.app"

if [[ "$NO_OPEN" -eq 0 ]]; then
  open "$OUT"
fi

echo ""
echo "✅ Video Screen Saver Generator built and passed all three verification passes."
echo "   $OUT/Video Screen Saver Generator.app"
echo ""
echo "Verification report: $REPORT"

if [[ "$NON_INTERACTIVE" -eq 0 ]]; then
  read -n 1 -s -r -p "Press any key to close…"
  echo
fi
