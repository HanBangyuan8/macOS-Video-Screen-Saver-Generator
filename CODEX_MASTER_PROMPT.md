# macOS Video Screen Saver Generator — Codex Master Prompt

You are working on **macOS-Video-Screen-Saver-Generator**, whose user-facing app is **Video Screen Saver Generator**, a native macOS utility that converts a user-selected video into an installable `.saver` screen saver. Work directly in this repository. Do not merely review or propose changes: inspect the reference repositories, implement the redesign, build it, run the verification suite, fix failures, and leave the repository in a shippable state.

## 0. Primary objective

Keep the **existing SaverForge v3.1 functional implementation as the authoritative baseline**, while rebuilding and polishing the **SwiftUI app UI** so it belongs to the same product family as my other macOS apps.

The final result should feel visually and behaviorally consistent with these repositories:

1. **Primary UI reference:** `HanBangyuan8/Audio-Convolution-Reverb`
2. **Secondary UI/reference-system source:** `HanBangyuan8/AudioLink-Lab`

Before editing the supplied project, inspect those repositories first. Do not imitate them from memory. Read the actual current source.

At minimum inspect:

### Audio-Convolution-Reverb
- `Sources/AudioConvolutionReverbApp/AudioConvolutionReverbApp.swift`
- `Sources/AudioConvolutionReverbApp/MotionSystem.swift`
- `Sources/AudioConvolutionReverbApp/VersionedNonlinearMotion.swift`
- `Sources/AudioConvolutionReverbApp/Launcher.swift`

### AudioLink-Lab
- `Apps/AudioLinkMac/Sources/AudioLinkMac/AudioLinkLabApp.swift`
- `Apps/AudioLinkMac/Sources/AudioLinkMac/MotionSystem.swift`
- `Apps/AudioLinkMac/Sources/AudioLinkMac/AdaptiveLayoutSystem.swift`
- representative page files such as `NewMeasurementView.swift`, `MeasurementHistoryView.swift`, and any shared sidebar/panel/settings UI used by the current app.

The two reference apps already share a common visual language. Preserve that language rather than inventing a third one.

---

## 1. Non-negotiable functional baseline

The supplied **SaverForge v3.1 baseline** already has a working functional architecture. **Do not replace it with a different screen-saver architecture. Do not move the screen saver implementation back to Swift.**

The current structure is intentional:

- Swift / SwiftUI: desktop app UI and export workflow
- Objective-C: actual `.saver` implementation
- Shell: build, signing, smoke tests, diagnostics

### Files whose behavior is authoritative

- `Sources/ScreenSaver/VideoScreenSaverView.h`
- `Sources/ScreenSaver/VideoScreenSaverView.m`
- `Sources/App/Exporter.swift`
- `Sources/SmokeTest/SaverSmokeTest.m`
- `build.command`
- `diagnose.command`
- `Resources/Saver-Info.plist`
- `Resources/SaverConfig.plist`
- `TestAssets/smoke.mp4`

You may refactor code organization if there is a strong engineering reason, but **must preserve all validated behavior** below.

### Screen saver invariants

The generated `.saver` must remain a native legacy ScreenSaver bundle with:

- `NSPrincipalClass = VideoScreenSaverView`
- `VideoScreenSaverView : ScreenSaverView`
- Objective-C screen saver implementation
- `AVQueuePlayer`
- `AVPlayerLooper`
- `AVPlayerLayer`
- embedded video under `.saver/Contents/Resources/video.<ext>`
- `fit` → `AVLayerVideoGravityResizeAspect`
- `fill` → `AVLayerVideoGravityResizeAspectFill`
- mute configuration from `SaverConfig.plist`
- safe asynchronous asset loading
- no crash if the embedded video is missing, unreadable, or invalid
- proper player/looper/layer teardown
- `com.apple.screensaver.willstop` lifecycle handling
- aggressive legacy-host cleanup only when the process is actually the dedicated `legacyScreenSaver` host and the view is not a preview
- never call `exit()` from Video Screen Saver Generator.app, System Settings preview, or the smoke-test host

Do not substitute `VideoPlayer`, SwiftUI, WebKit, WKWebView, SpriteKit, Metal, or a custom helper app for the current screen saver implementation unless a verified macOS bug makes it strictly necessary. Simplicity and reliability win.

### Export/signing invariants

`Exporter.swift` must preserve the current sequence and semantics:

1. validate source video exists and is non-empty
2. locate and validate embedded `.saver` template
3. copy the template to a staging `.saver`
4. remove any previous `video.*` resources
5. copy the selected video into the generated bundle
6. write `SaverConfig.plist`
7. rewrite display name / bundle identifier / build version / principal class
8. recursively strip extended attributes from the **generated staging bundle only** using `xattr -c -r`
9. never strip xattrs from, mutate, transcode, or otherwise modify the user's original source video
10. remove stale signature if possible
11. ad-hoc sign the generated `.saver`
12. verify with `codesign --verify --strict`
13. preserve complete exit code/stdout/stderr diagnostics on failure
14. only then move the staging bundle to the final destination

Preserve safe ASCII bundle identifier generation for Chinese, Japanese, emoji, punctuation, and other non-ASCII display names.

### Build/verification invariants

The project deliberately uses `xcrun clang` / `xcrun swiftc` rather than requiring an Xcode project. Keep this lightweight approach unless there is a compelling reason to introduce a project file.

The app and screen saver must remain **Universal 2: arm64 + x86_64**.

The current three-pass verification philosophy must remain and should be strengthened, not weakened:

- PASS 1: source / plist / SDK syntax / architectural invariant checks
- PASS 2: built artifact / architectures / bundle / exported Obj-C class / frameworks / codesign integrity
- PASS 3: generated `.saver` runtime smoke test, including the extended-attribute signing regression, `NSBundle` load, `NSPrincipalClass`, preview/full instantiation, and start/stop lifecycle

Do not report success unless all three passes actually pass on macOS.

---

## 2. UI design task — first duplicate the existing product language

The current supplied UI is only a functional prototype. Replace its visual layer with the same design language used by `Audio-Convolution-Reverb` and `AudioLink-Lab`.

This does **not** mean blindly copying an entire unrelated screen. Extract and reuse the design system and interaction patterns.

### Required shared design language

Inspect the reference apps and reproduce their current patterns for:

- native macOS SwiftUI hierarchy
- `NavigationSplitView` / native sidebar behavior where appropriate
- sidebar row selection treatment
- window sizing and adaptive behavior
- material-backed panels/cards
- continuous rounded corners
- restrained shadows and borders
- system typography hierarchy
- SF Symbols
- accent-color system
- motion intensity system
- hover and press feedback
- page/section appearance transitions
- accessibility Reduce Motion support
- light/dark appearance correctness
- toolbar semantics
- spacing rhythm and content margins
- native controls instead of bespoke web-style controls

Prefer reusing/adapting the existing reference components/tokens instead of creating nearly identical duplicates under new names.

In particular, inspect and reuse the concepts represented by:

- `MotionTokens`
- `MotionIntensity`
- `LightweightPressButtonStyle`
- hover modifiers
- panel modifiers
- sidebar button styles
- accent-color picker/palette
- adaptive layout metrics
- native/compatibility topology where it actually matters

If the same helper is literally identical in both reference repos, treat that as evidence that it is part of the shared house style.

### Do not over-design

Video Screen Saver Generator has a much smaller information architecture than the audio apps. Keep it focused. Do not manufacture empty pages merely to justify a sidebar.

A good target topology is:

- **Create** — the main screen saver creation workflow
- **Settings** — appearance / behavior preferences only if there are enough meaningful settings
- optional **About / Diagnostics** only if it contains real value

If one primary page plus a compact sidebar is cleaner and consistent, use that. If a full sidebar makes the app worse, retain a single-window composition but use the same cards, motion, tint, material, spacing, and toolbar system. Consistency matters more than copying layout mechanically.

---

## 3. Main workflow UX

Design the app around a clear one-direction workflow:

### Step A — Choose video

Support both:

- native file picker
- drag and drop onto a large video drop/preview surface

Accepted types should remain movie types that the existing AVFoundation path can consume. Do not pretend unsupported formats are guaranteed.

After selection show useful metadata when available without blocking the UI, for example:

- file name
- container/extension
- duration
- dimensions
- file size

Metadata failures should degrade gracefully.

### Step B — Preview

Maintain in-app playback preview.

Requirements:

- loop reliably
- respect mute toggle immediately
- no stale AVPlayer observer leaks when replacing files
- pause/release correctly when the view disappears
- show a deliberate empty state before video selection
- preview surface should visually match the reference apps, not look like a raw black rectangle pasted into a form

### Step C — Configure

At minimum retain:

- screen saver display name
- Fill / Fit
- mute

Present them in the same settings-row / material-panel language as the other apps.

Do not expose legacy cleanup or signing internals as casual end-user toggles.

### Step D — Export / Install

Keep both actions:

- Export `.saver…`
- Generate and Install

The primary and secondary button hierarchy must be obvious.

For long video copies/signing:

- show progress/busy state
- disable conflicting actions
- keep the app responsive
- do heavy file/signing work off the main actor where practical
- return UI state changes to the main actor safely

Do not fake a percentage if true progress is unavailable. An indeterminate progress state is better than dishonest progress.

### Success state

After successful export/install, show a polished result state containing the final path and useful next action(s).

Do not rely on undocumented System Settings URL schemes unless verified on the minimum supported macOS versions. If opening the Screen Saver settings pane is implemented, make it best-effort and never make successful export depend on it.

### Failure state

Errors must be understandable at two levels:

1. concise user-facing summary
2. expandable/copyable technical details for diagnosis, especially full `codesign` failure output

Never hide the actual subprocess exit code/stderr again.

---

## 4. Appearance and preferences

Bring Video Screen Saver Generator into the same family as the other apps.

Implement, where appropriate:

- shared accent-color palette consistent with the reference repos
- default accent matching the current house default
- `MotionIntensity`: Enhanced / Reduced / Off
- respect `accessibilityReduceMotion`
- persistent preferences through `@AppStorage`
- native light/dark/system appearance behavior; do not hardcode a fake dark theme

If adding language selection, implement it cleanly and consistently with the reference apps. Do not add a half-finished localization layer. English + Simplified Chinese + Traditional Chinese is acceptable only if all visible app strings are covered.

---

## 5. Architecture and code quality

The current prototype has too much UI in `ContentView.swift`. Refactor only the SwiftUI/app layer into clear, maintainable units.

A reasonable direction:

- `VideoScreenSaverGeneratorApp.swift` (or retain `SaverForgeApp.swift` temporarily only during migration, then finish the product rename cleanly)
- `ContentView.swift` / app shell
- `CreateSaverView.swift`
- `VideoPreviewView.swift`
- `VideoPreviewController.swift`
- `SaverSettingsView.swift`
- `AppearanceSettingsView.swift` if needed
- `DesignSystem.swift` or reused house-style components
- `MotionSystem.swift` adapted from the reference repos
- `AdaptiveLayoutSystem.swift` if genuinely useful
- `Exporter.swift`
- optional `VideoMetadata.swift`

Do not create abstraction for abstraction's sake. Avoid giant files, but also avoid dozens of one-function files.

### Concurrency

Audit the app for main-thread blocking. Video copying and `codesign` can be expensive. Keep UI updates on the main actor and run blocking work outside the UI thread. Preserve deterministic error handling.

### Memory/lifecycle

Audit:

- AVPlayer lifetime
- notification observers
- replacement of selected videos
- window/view disappearance
- repeated export/install operations
- screen saver preview/full lifecycle

There must be no obvious retain cycle or accumulating observer/player instance.

---

## 6. Preserve the screen saver core unless a test proves a bug

The Objective-C screen saver is intentionally boring. That is a feature.

Do not rewrite `VideoScreenSaverView.m` merely to make the code style match the Swift app.

If you discover a real defect:

1. reproduce it
2. add or strengthen a regression test
3. make the smallest fix
4. run all three passes
5. document the reason

Otherwise leave the screen saver engine functionally unchanged.

---


## 7. Distribution / packaging parity with my other macOS repositories

The product family is not defined only by UI. **Build artifacts, packaging, signing, DMG layout, icon generation, release naming, metadata cleanup and release validation must also match my existing macOS repositories.**

Before implementing release tooling, inspect the CURRENT versions of these files in `HanBangyuan8/AudioLink-Lab` and treat them as the primary distribution reference:

- `Scripts/package-app.sh`
- `Scripts/package-dmg.sh`
- `Scripts/generate-app-icon.swift`
- `Scripts/release.sh`
- `Scripts/check-architecture.sh`
- `Resources/AppIcon.icns` / `Resources/AppIcon.png` conventions

Also inspect any equivalent packaging/release tooling that exists in `HanBangyuan8/Audio-Convolution-Reverb`. If both repositories implement the same concern, prefer the newer/more complete shared convention rather than inventing a new third pipeline.

### 7.1 Repository/product naming

Use a descriptive repository identity instead of the prototype name `SaverForge`. The preferred repository name is:

`macOS-Video-Screen-Saver-Generator`

Preferred user-facing product name:

`Video Screen Saver Generator`

Preferred executable stem:

`VideoScreenSaverGenerator`

Preferred bundle identifier, unless an existing naming convention in my current repositories clearly indicates another equivalent form:

`com.han.VideoScreenSaverGenerator`

Do not blindly mass-replace low-level screen saver class names such as `VideoScreenSaverView`; those names are implementation identifiers and can remain stable when changing them would add risk.

Release artifact naming should follow the same pattern as AudioLink-Lab, adapted to this repository, e.g.:

`macOS-Video-Screen-Saver-Generator-v${VERSION}-macOS-universal.app`
`macOS-Video-Screen-Saver-Generator-v${VERSION}-macOS-universal.zip`
`macOS-Video-Screen-Saver-Generator-v${VERSION}-macOS-universal.dmg`

The installed app itself should remain cleanly named:

`Video Screen Saver Generator.app`

### 7.2 Universal app packaging

Mirror the established `package-app.sh` strategy from AudioLink-Lab:

- build arm64 and x86_64 separately on macOS
- merge with `lipo -create`
- explicitly verify both architectures
- construct a standard `.app/Contents/{MacOS,Resources}` bundle
- generate the app Info.plist deterministically
- set product display name, executable, bundle ID, semantic version, build version, deployment target and AppIcon fields explicitly
- keep build staging in `mktemp` and clean it with a trap
- place finished release artifacts under `dist/`
- do not package build caches, user data, temporary media, generated state, logs or preview caches

Retain the current ScreenSaver template inside the app resources exactly where the exporter expects it. Packaging changes must not break template discovery.

### 7.3 Bundle metadata cleaning

Match the robust metadata cleaning used by AudioLink-Lab before signing and after copying:

- delete AppleDouble `._*` files
- `dot_clean -m` where available
- `xattr -cr` / equivalent recursive xattr cleanup on GENERATED/PACKAGED ARTIFACTS
- remove problematic `com.apple.FinderInfo` and file-provider metadata where necessary
- use `ditto --norsrc` for bundle copies where appropriate

**Never apply this cleanup to the user's original selected video.** The source video must remain byte-for-byte and metadata-for-metadata untouched by the app.

Keep/add a packaging guard analogous to AudioLink-Lab's user-cache payload assertion so release `.app`/`.dmg` artifacts cannot accidentally contain local user state.

### 7.4 Signing must match the existing repository convention

Do not silently change the project to Developer ID signing or notarization just because that would be a more conventional public-distribution setup. My current reference release pipeline uses ad-hoc signing. Match it unless I explicitly request a migration later.

For the packaged APP, mirror the established sequence:

1. clean generated bundle metadata
2. `codesign --force --deep --sign - <App>`
3. clean generated bundle metadata again if required by the established pipeline
4. `codesign --verify --deep --strict <App>`
5. after final `ditto` copy, verify the final artifact again

For GENERATED `.saver` bundles inside the app's runtime workflow, retain SaverForge v3.1's stricter specialized signing logic and xattr regression protection; do not replace that with a less precise generic command merely to make the shell scripts look uniform.

The release manifest must truthfully represent the signing state. If using ad-hoc signing, do not claim Developer ID signing or notarization.

### 7.5 DMG structure

Match AudioLink-Lab's DMG structure and commands unless there is a demonstrated screen-saver-specific reason not to:

DMG root:

```text
Video Screen Saver Generator.app
Applications -> /Applications
```

Requirements:

- stage a clean copy of the packaged app
- re-verify/re-sign the staged copy using the same established ad-hoc process
- include `/Applications` as a symbolic link
- no unnecessary README/license clutter in the DMG root unless the reference repositories add it
- create with `hdiutil create`
- volume name should include product name + version
- use compressed `UDZO` format, matching AudioLink-Lab
- produce BOTH `.zip` and `.dmg` release artifacts
- generate SHA-256 files for release artifacts in the release workflow, matching the reference repository behavior

Do not introduce a custom DMG background/layout tool unless an existing reference repository already uses one. Exact product-family consistency is more important than decorative DMG customization.

### 7.6 App icon generation

Use the SAME GENERATION APPROACH as `AudioLink-Lab/Scripts/generate-app-icon.swift` rather than manually committing an arbitrary single PNG.

Create/adapt `Scripts/generate-app-icon.swift` using AppKit/Foundation and generate the standard complete iconset variants:

- 16x16
- 16x16@2x
- 32x32
- 32x32@2x
- 128x128
- 128x128@2x
- 256x256
- 256x256@2x
- 512x512
- 512x512@2x (1024 px backing image)

The generator must emit:

- `Resources/AppIcon.iconset/...`
- `Resources/AppIcon.icns`
- `Resources/AppIcon.png` as a README/repository preview

Keep the same robust ICNS-generation strategy and Finder/DMG rendering compatibility used by the sibling repo.

The ARTWORK itself must be app-specific rather than copying AudioLink-Lab's waveform logo. Design a simple native macOS icon for video → screen saver conversion, ideally using the same product-family visual discipline: a rounded macOS icon body, controlled gradient, high legibility at 16 px, and a minimal screen/video/screen-saver motif. Do not put text inside the icon.

Verify the icon visually at all generated sizes, especially 16, 32, 128, 512 and 1024 backing sizes. Small icons must not collapse into indistinct detail.

### 7.7 Release script parity

Create/adapt a `Scripts/release.sh` flow consistent with AudioLink-Lab. At minimum it should:

1. clean relevant build outputs
2. run tests/validation
3. run the project's three screen-saver validation passes
4. package Universal 2 app
5. package ZIP + DMG
6. verify architecture
7. verify app and saver signatures
8. produce SHA-256 checksum sidecars
9. create a source archive excluding `.git`, build products, caches, `dist`, `.DS_Store`, generated iconset intermediates and other disposable state
10. emit a truthful `release-manifest.json` including version/build, platform architectures, artifact names, signing status, notarization status and validation result

Do not mark ad-hoc artifacts as Developer-ID signed. Do not mark them as notarized.

### 7.8 Packaging QA

The final release QA must validate all of these, not merely that the app compiles:

- AppIcon exists and is referenced correctly in Info.plist
- Finder shows the correct generated icon
- Universal 2 app binary
- Universal 2 embedded `.saver` binary
- packaged app opens
- packaged app can generate a `.saver`
- generated `.saver` passes the existing runtime smoke test
- final app codesign verification passes
- ZIP extracts without corruption
- DMG mounts successfully
- DMG contains exactly the intended top-level app and Applications link
- app copied from mounted DMG still verifies and launches
- no `.DS_Store`, AppleDouble, local cache, user history, source test video or unrelated developer state leaks into the release bundle
- SHA-256 checksum files match their artifacts
- source archive contains source/scripts/docs but no generated build/cache output

Packaging/release parity is a first-class acceptance criterion, not optional polish.

---
## 8. Build script updates required by UI refactor

Because `build.command` invokes `swiftc` directly, if you split SwiftUI into additional `.swift` files, update both:

- PASS 1 Swift parser invocation
- each architecture's `swiftc` build invocation

Prefer collecting the app Swift sources deterministically rather than maintaining two mismatched hard-coded lists. For example, a sorted source-array assembled from `Sources/App/*.swift` is acceptable if it remains explicit, shell-safe, reproducible, and excludes tests.

Add any newly required Apple frameworks explicitly.

Do not accidentally drop Universal 2.

---

## 9. Verification work you must perform

Do not stop after the UI compiles.

### A. Reference/UI audit

Before implementation, inspect the reference repositories and write a short internal checklist of the exact design primitives you are reusing. Do not ask me to identify them for you.

### B. Static/source checks

Run/extend PASS 1. Ensure:

- every plist validates
- every Swift source parses
- Objective-C screen saver passes SDK syntax check
- no accidental Swift dependency is introduced into the `.saver`
- `NSPrincipalClass` remains correct
- core lifecycle invariants remain present

### C. Release build checks

Run PASS 2. Confirm:

- Video Screen Saver Generator app executable arm64 + x86_64
- embedded VideoScreenSaver.saver arm64 + x86_64
- signatures verify
- screen saver Obj-C class is exported
- ScreenSaver/AppKit/AVFoundation/QuartzCore linking remains correct
- app opens normally

### D. Runtime screen saver checks

Run PASS 3 exactly on a generated `.saver`, not only the empty template.

Preserve the xattr regression test:

- deliberately add an extended attribute to the test video/bundle
- confirm it exists
- run the same cleanup path
- confirm it is gone
- sign
- verify
- load bundle dynamically
- resolve principal class
- instantiate preview
- start/stop
- instantiate full-size saver
- start/stop

### E. App workflow test

Also manually or programmatically exercise at least:

1. launch app
2. choose/drop the smoke video
3. replace it with another selection or reselect
4. toggle mute
5. switch Fit/Fill
6. export a `.saver`
7. verify generated bundle
8. generate/install to a temporary controlled destination or safely test install logic
9. repeat export to catch stale state/resource leaks
10. test a Unicode screen saver name
11. test a source file carrying xattrs
12. test cancellation from Open/Save panel
13. test failure diagnostics without crashing

### F. UI QA

Check at minimum:

- light mode
- dark mode
- Reduce Motion on/off
- minimum supported window size
- default window size
- narrow but valid window resize
- long file name
- long screen saver name
- no selected file
- busy state
- success state
- error state

No clipped controls, overlapping text, unreadable material, or inaccessible low-contrast selection state.

---

## 10. Acceptance criteria

The task is complete only when all are true:

- Video Screen Saver Generator looks recognizably from the same developer/product family as `Audio-Convolution-Reverb` and `AudioLink-Lab`.
- UI patterns are based on actual reference source, not an approximation.
- The app remains a native macOS SwiftUI app.
- The `.saver` remains Objective-C + ScreenSaver.framework.
- Existing v3.1 screen saver behavior is preserved.
- Exported video is embedded and independent from its original source path.
- Fill / Fit / mute work.
- Unicode saver names produce valid bundle identifiers.
- xattr-contaminated user videos no longer break signing.
- technical signing failures preserve full diagnostics.
- app stays responsive during export/signing.
- no obvious AVPlayer/observer leak exists.
- Universal 2 is preserved for both app and saver.
- all three verification passes succeed.
- the app workflow itself has been exercised after the UI rewrite.
- README is updated to describe the final UI/workflow/build instructions accurately.

---

## 11. Change discipline

Do not rewrite working low-level code gratuitously.

Before modifying a functional core file, ask yourself whether the same goal can be achieved entirely in the SwiftUI/app layer. If yes, leave the core alone.

Do not delete diagnostics or tests to make the build green.
Do not weaken codesign verification.
Do not remove xattr cleanup.
Do not remove the full error output.
Do not remove the legacy will-stop guard.
Do not remove Universal 2.
Do not convert the `.saver` to Swift.
Do not use a web UI.
Do not add third-party dependencies unless they provide a major, demonstrated benefit that cannot be achieved cleanly with Apple frameworks.

---

## 12. Execution order

Execute this in one continuous engineering pass:

1. inspect the supplied SaverForge v3.1 baseline and understand its validated behavior
2. inspect both reference repos and identify the shared UI system
3. make a concise implementation plan internally
4. extract/adapt shared UI primitives
5. refactor the SwiftUI layer and complete the product/repository rename to Video Screen Saver Generator / macOS-Video-Screen-Saver-Generator
6. preserve/integrate existing exporter and screen saver core
7. make export/signing asynchronous and UI-safe if needed
8. improve success/error/busy states
9. update build script for all new Swift files/frameworks
10. update README
11. run PASS 1
12. fix everything until PASS 1 passes
13. build Universal 2
14. run PASS 2
15. fix everything until PASS 2 passes
16. run PASS 3
17. fix everything until PASS 3 passes
18. exercise the actual app workflow and UI states
19. inspect git diff for accidental core regressions
20. provide a final concise report containing:
    - reference UI primitives reused
    - files changed/added
    - functional changes
    - core files intentionally preserved
    - exact validation commands run
    - PASS 1/2/3 results
    - any remaining known limitation

Do **not** stop at a design proposal and do **not** ask me to manually copy styles. Read the repositories and implement them yourself.

## Final priority order

When requirements compete, prioritize in this order:

1. screen saver reliability and no crashes
2. preservation of v3.1 validated export/signing behavior
3. truthful verification
4. native macOS UX
5. consistency with my other repositories
6. polish and animation

The desired outcome is a small, highly polished Mac utility whose UI clearly matches my existing apps while its low-level `.saver` engine remains conservative, stable, and thoroughly verified.
