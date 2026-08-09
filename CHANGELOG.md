# Changelog

## v1.0.5 - 2026-08-09

Balanced Create panel sizing.

- Measured the preview and settings panels at their intrinsic content heights and used the taller panel as the shared height.
- Removed the settings-panel spacer that could incorrectly expand both visible boxes to the full window height.
- Preserved the Latency-style panel frame, border, and hover behavior after the shared height is resolved.
- Updated the application and release defaults to version 1.0.5 (build 6).

## v1.0.4 - 2026-08-09

Create layout and interaction polish.

- Kept the Create page in a native left/right split and made the preview and settings panels share the same resolved height.
- Applied the Latency-style panel frame after the shared height so the visible borders, hover area, scale, and shadow stay aligned.
- Restored the Latency-style control and panel hover treatment while preserving the native macOS 15+ shell and fixed application title.
- Updated the application and release defaults to version 1.0.4 (build 5).

## v1.0.3 - 2026-08-09

Latency UI source duplication and shell refactor.

- Duplicated the Latency-style `AppModel`, `NativeModernContentView`, native sidebar sections, per-page detail branches, `SettingsPage`/`SettingsPanel`, and model-driven `AccentColorPicker` structure into the app.
- Connected the existing Create workflow to the shared app model for language, accent color, motion, locale, runtime profile, and export defaults.
- Kept directional page transitions, versioned Motion optimization, and hover-independent visual styling intact after the structural refactor.
- Updated the application and release defaults to version 1.0.3 (build 4).

## v1.0.2 - 2026-08-09

Directional motion and visual consistency update.

- Forced the Latency-style page transition pipeline to use the navigation direction for both the asymmetric transition and versioned page-settle motion.
- Removed hover-dependent background, border, shadow, and scale changes so the app has the same visual appearance with or without a pointer over a control or panel.
- Kept the duplicated Latency MotionSystem, VersionedNonlinearMotion, runtime optimization profile, native shell, accent palette, language layer, and Settings topology in sync.
- Updated the application and release defaults to version 1.0.2 (build 3).

## v1.0.1 - 2026-08-09

UI and motion refresh.

- Rebuilt the SwiftUI shell around the native macOS `NavigationSplitView` top bar and sidebar pattern used by Latency Graph for ClashX Meta.
- Added the same versioned vertical page-switch motion, startup motion, component reveals, press feedback, and runtime-aware optimization profile.
- Added the matching 16-color accent palette with animated selection and localized accessibility labels.
- Added English, Simplified Chinese, and Traditional Chinese UI language switching across the shell, Create workflow, preview, and Settings page.
- Reworked Settings into the native section/card layout with appearance, screen saver defaults, export safety, Universal 2, signing, and diagnostics sections.
- Preserved the existing video preview/export/install workflow and connected new-export defaults to Settings.

## v1.0.0 - 2026-08-09

Initial public release.

- Added a native SwiftUI workflow for choosing, previewing, configuring, exporting, and installing local videos as screen savers.
- Added Fill / Fit display modes, mute control, drag-and-drop video selection, metadata loading, Unicode-safe saver names, and responsive busy/success/error states.
- Preserved the Objective-C `ScreenSaverView` engine with embedded video resources, AVQueuePlayer/AVPlayerLooper playback, legacy lifecycle protection, and Universal 2 support.
- Added xattr-safe generated bundle cleanup and strict ad-hoc signing while keeping the original source video byte-for-byte and metadata-for-metadata untouched.
- Added three-pass source, artifact, and runtime validation with app workflow QA and detailed signing diagnostics.
- Added Universal 2 app packaging, generated AppKit icon assets, clean ZIP and compressed UDZO DMG artifacts, SHA-256 sidecars, and a truthful release manifest.
- Licensed under the Mozilla Public License 2.0.
