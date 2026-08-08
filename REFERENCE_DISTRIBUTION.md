# Distribution reference

Primary current reference: `HanBangyuan8/AudioLink-Lab`.

Codex must inspect the live repository before implementation, especially:

- `Scripts/package-app.sh`
- `Scripts/package-dmg.sh`
- `Scripts/generate-app-icon.swift`
- `Scripts/release.sh`
- `Scripts/check-architecture.sh`

Expected product-family conventions:

- Universal 2 (arm64 + x86_64)
- `lipo` merge and architecture verification
- manually constructed standard macOS app bundle
- metadata cleanup (`._*`, `dot_clean`, xattr cleanup) on generated artifacts
- ad-hoc app signing (`codesign --force --deep --sign -`) and strict verification
- final bundle re-verification after `ditto --norsrc` copy
- ZIP + compressed UDZO DMG
- DMG root: application + `Applications -> /Applications` symlink
- product + version volume name
- SHA-256 sidecars
- truthful release manifest (`signed: false`, `notarized: false` while ad-hoc)
- Swift/AppKit-generated full AppIcon iconset + `AppIcon.icns` + `AppIcon.png` preview

SaverForge's runtime-generated `.saver` has stricter specialized signing/xattr requirements and must retain those even when the outer app packaging is made consistent.
