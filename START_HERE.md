# Codex Handoff — macOS Video Screen Saver Generator

This directory is the complete engineering handoff.

## First action

Read `CODEX_MASTER_PROMPT.md` in full and execute it as the authoritative task specification.

Do not begin implementation from this file alone.

## Repository name

Use:

`macOS-Video-Screen-Saver-Generator`

Recommended product naming:

- App display name: `Video Screen Saver Generator`
- Executable: `VideoScreenSaverGenerator`
- Bundle identifier: `com.han.VideoScreenSaverGenerator`

## Authoritative baseline

The current validated functional baseline is the included SaverForge v3.1 source.

Before changing low-level functionality, read:

- `SOURCE_BASELINE_SHA256.txt`
- `Sources/ScreenSaver/VideoScreenSaverView.h`
- `Sources/ScreenSaver/VideoScreenSaverView.m`
- `Sources/App/Exporter.swift`
- `build.command`
- `diagnose.command`

The Objective-C `.saver` engine, xattr cleanup, signing chain, legacy screen-saver lifecycle workaround, Universal 2 requirements, and three-pass validation are deliberate reliability decisions.

## Required external reference repositories

Inspect their current source before implementing UI or release tooling:

1. `HanBangyuan8/Audio-Convolution-Reverb`
2. `HanBangyuan8/AudioLink-Lab`

Use those repositories as the source of truth for the user's shared macOS product language, including UI, motion, adaptive layout, application packaging, icon generation, artifact naming, ad-hoc signing, DMG layout, release scripts, checksums, and release-manifest conventions.

Supporting notes are included in:

- `REFERENCE_UI.md`
- `REFERENCE_DISTRIBUTION.md`

These notes are orientation only; the live reference repositories remain authoritative.

## Required end state

Implement a polished native macOS application that:

- visually belongs to the same product family as the reference apps;
- preserves the stable Objective-C ScreenSaver.framework implementation;
- embeds the selected video in every generated `.saver`;
- supports Fill / Fit and mute;
- handles Unicode names and xattr-contaminated source videos;
- keeps export/signing work off the main UI thread;
- remains Universal 2 for both app and screen saver;
- uses the same packaging/signing/DMG/icon/release conventions as the reference repos;
- passes all three validation passes plus actual app workflow QA;
- leaves release-ready scripts and documentation in the repository.

## Execution instruction

After reading this file, read `CODEX_MASTER_PROMPT.md` and perform the entire task continuously. Do not stop at analysis or return only a proposal.
