# Changelog

## v1.0.0 - 2026-08-09

Initial public release.

- Added a native SwiftUI workflow for choosing, previewing, configuring, exporting, and installing local videos as screen savers.
- Added Fill / Fit display modes, mute control, drag-and-drop video selection, metadata loading, Unicode-safe saver names, and responsive busy/success/error states.
- Preserved the Objective-C `ScreenSaverView` engine with embedded video resources, AVQueuePlayer/AVPlayerLooper playback, legacy lifecycle protection, and Universal 2 support.
- Added xattr-safe generated bundle cleanup and strict ad-hoc signing while keeping the original source video byte-for-byte and metadata-for-metadata untouched.
- Added three-pass source, artifact, and runtime validation with app workflow QA and detailed signing diagnostics.
- Added Universal 2 app packaging, generated AppKit icon assets, clean ZIP and compressed UDZO DMG artifacts, SHA-256 sidecars, and a truthful release manifest.
- Licensed under the Mozilla Public License 2.0.
