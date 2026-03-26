# PulseDeck IPA Export on macOS

This project can be prepared on Linux, but archive creation, code signing, and IPA export must happen on macOS with Xcode.

## Prerequisites

1. macOS with Xcode 15 or newer installed
2. An Apple Developer account and signing access
3. A unique bundle identifier replacing `com.example.PulseDeck`
4. Real app icons added to `PulseDeck/Resources/Assets.xcassets/AppIcon.appiconset`
5. A physical iPhone for final live-signal validation

## First open in Xcode

1. Open `PulseDeck.xcodeproj`.
2. Select the shared `PulseDeck` scheme.
3. Set your signing team in the target’s `Signing & Capabilities` tab.
4. Replace the default bundle identifier.
5. Run once on a device and once in Simulator to catch signing/layout issues.

## If the project file needs regeneration

Run this on macOS:

```bash
./scripts/regenerate_xcode_project.sh
```

That uses `project.yml` and XcodeGen to rebuild `PulseDeck.xcodeproj`.

## Archive flow in Xcode

1. In Xcode, choose `Any iOS Device (arm64)` or a connected device.
2. Use `Product > Archive`.
3. Wait for Organizer to open with the new archive.
4. Validate the archive.
5. Export with the distribution method you actually need:
   - App Store Connect
   - Ad Hoc
   - Development
   - Enterprise

## CLI archive/export flow

Use the helper script:

```bash
./scripts/archive_ipa.sh \
  --development-team YOURTEAMID \
  --bundle-id com.yourcompany.PulseDeck \
  --export-options export/ExportOptions-AppStore.plist.example
```

The script is intentionally conservative:

- It exits immediately on non-macOS hosts
- It requires `xcodebuild`
- It expects you to provide signing/team values
- It does not pretend to auto-solve provisioning

## Manual `xcodebuild` reference

Archive:

```bash
xcodebuild \
  -project PulseDeck.xcodeproj \
  -scheme PulseDeck \
  -configuration Release \
  -destination generic/platform=iOS \
  DEVELOPMENT_TEAM=YOURTEAMID \
  PRODUCT_BUNDLE_IDENTIFIER=com.yourcompany.PulseDeck \
  clean archive \
  -archivePath build/PulseDeck.xcarchive
```

Export:

```bash
xcodebuild \
  -exportArchive \
  -archivePath build/PulseDeck.xcarchive \
  -exportPath build/export \
  -exportOptionsPlist export/ExportOptions-AppStore.plist
```

## Recommended pre-export checklist

- Replace the placeholder bundle identifier
- Confirm signing team/profiles resolve cleanly
- Add final app icons
- Verify motion/battery behavior on a real device
- Check that live mode does not overclaim throughput
- Confirm demo mode is clearly labeled before recording screenshots or videos
- Archive with `Release`
