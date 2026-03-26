# PulseDeck

PulseDeck is a SwiftUI iPhone app concept for real-time phone-performance monitoring that stays inside standard iOS app boundaries. The app is styled like a polished neon control deck, but the telemetry model stays explicit about what an App Store-safe iOS app can actually know.

## What changed in this pass

- Stronger dashboard polish with richer hero messaging, highlight tiles, watchlist alerts, animated cards, and clearer data-source labeling
- Better event model with explicit event origins (`System`, `Inferred`, `Demo`, `App`) and timeline filtering
- More complete settings for presentation tuning, timeline behavior, and project/export reminders
- Shared Xcode scheme, XcodeGen scheme config, and helper scripts/docs for later macOS archive and IPA export work
- GitHub Actions workflows for simulator CI and signed IPA export on macOS runners

## Trust model: real vs estimated vs placeholder

| Area | Tier | Notes |
| --- | --- | --- |
| Battery level/state | Real | Uses `UIDevice` battery monitoring. Often unavailable in Simulator. |
| Low Power Mode | Real | Uses `ProcessInfo.isLowPowerModeEnabled`. |
| Thermal state | Real | Uses `ProcessInfo.thermalState`. This is coarse and not a temperature sensor. |
| Storage usage | Real | Uses app-visible volume capacity APIs. It is device/container capacity, not detailed per-app cache breakdown. |
| Memory warnings | Real | Uses `UIApplication.didReceiveMemoryWarningNotification`. |
| App memory footprint | Estimated | Uses the current app process footprint when available. This is app-only, not whole-device RAM pressure. |
| App FPS | Estimated | Uses the app’s own `CADisplayLink` cadence. It does not measure other apps or the whole system compositor. |
| Network reachability | Real | Uses `NWPathMonitor` for online/offline/interface status. |
| Network throughput | Placeholder in live mode, estimated in demo mode | There is no private/silent scraping. Demo mode uses seeded Mbps curves; live mode intentionally does not fake them. |
| Motion/orientation | Real | Uses `UIDevice` orientation notifications and Core Motion device-motion updates. |
| Device info | Real | Public device and OS facts only. |

## Important iOS limitations

PulseDeck does **not** claim or fake these as live device truths:

- CPU temperature
- Battery temperature
- Total system CPU percentage
- Other apps’ memory usage
- Other apps’ FPS
- Private diagnostics from SpringBoard, IOKit, or non-public frameworks
- “Real-time network speed” without an explicit measurement path

If you want throughput later, the honest route is an explicit user-triggered benchmark flow with clear consent and clear labeling.

## Project layout

```text
ios-performance-monitor/
├── PulseDeck.xcodeproj/
│   └── xcshareddata/xcschemes/PulseDeck.xcscheme
├── PulseDeck/
│   ├── App/
│   ├── Core/
│   ├── Features/
│   ├── Shared/
│   └── Resources/
├── docs/
│   ├── github-actions-ios.md
│   └── ipa-export-macos.md
├── export/
│   ├── ExportOptions-AdHoc.plist.example
│   └── ExportOptions-AppStore.plist.example
├── scripts/
│   ├── archive_ipa.sh
│   └── regenerate_xcode_project.sh
├── README.md
└── project.yml
```

## Opening in Xcode on macOS

1. Open `ios-performance-monitor/PulseDeck.xcodeproj` in Xcode 15 or newer.
2. Select the shared `PulseDeck` scheme.
3. Set your own bundle identifier and signing team.
4. Add real app icons in `PulseDeck/Resources/Assets.xcassets/AppIcon.appiconset`.
5. Run on a physical iPhone for battery, thermal, and motion signals. Simulator is useful for layout and demo mode only.

If the project file ever needs regeneration, use `scripts/regenerate_xcode_project.sh` on macOS with XcodeGen installed.

## Cloud build / GitHub Actions

This repo now includes:

- `.github/workflows/pulsedeck-ci.yml`
  - builds the app for **iOS Simulator** on GitHub-hosted macOS without signing
- `.github/workflows/pulsedeck-ipa.yml`
  - imports your certificate/profile, archives the app, and exports a signed IPA artifact

Detailed setup is documented in:

- `ios-performance-monitor/docs/github-actions-ios.md`

## IPA export reality check

You cannot build or export a signed iOS IPA from this Linux workspace. Apple’s signing, archiving, and IPA export flow requires macOS and Xcode.

For the later macOS handoff:

- Read `docs/ipa-export-macos.md`
- Use `scripts/archive_ipa.sh` as a starting point
- Copy and customize one of the example `export/ExportOptions*.plist.example` files
- Or use the GitHub Actions workflow with your Apple signing secrets

## Linux caveat

This project was scaffolded and improved on Linux, so I could not run `xcodebuild`, validate compilation against Apple SDKs, or produce an `.xcarchive`/`.ipa` here. The source tree, shared scheme, XcodeGen spec, helper docs, and GitHub Actions workflows are included specifically to make the eventual macOS/Xcode or cloud-CI step smoother.
