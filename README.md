# TurboRacer: Afterlight

A native offline arcade racing adventure for iPhone and iPad. The original 2024 Unity export remains at the repository root as an archive. Active development is in **Afterlight/**; no Unity installation is required.

## Play

Inherit your father's Solstice, rebuild the garage with mechanic Mika, and join the Afterlight Festival. Race from Palm Coast through Neon Harbor and Ember Canyon to Cloudline. Earn five campaign stars in each region to open the next.

- Four original 3D circuits with distinct scenery, skies, and regional rivals.
- Twelve campaign events: two-lap races with three rivals, time attack, and drift runs.
- Six fictional cars with individual paint, proportions, performance, and earned engine tuning.
- Automatic acceleration, touch steering, braking, drift combos, nitro, off-road penalties, and rival collisions.
- Twelve memory sparks per circuit: collect them to recharge nitro, earn credits, and recover four notebook pages in the story journal.
- Daily rotating drift challenge; the first starred run awards 350 extra credits.
- Persistent garage, best times, drift records, stars, statistics, and milestones.
- Original generated cover/icon art and a reproducible synth score. No ads, purchases, accounts, analytics, or external game services.

## Build

Open `Afterlight/Afterlight.xcodeproj` in Xcode. Select the **Afterlight** scheme and a simulator or signing-enabled iOS device. Deployment target: iOS 17.

The committed Xcode project is generated from `Afterlight/project.yml`. When changing project structure, run:

```sh
xcodegen generate --spec Afterlight/project.yml
```

## Verify

```sh
xcodebuild -project Afterlight/Afterlight.xcodeproj -scheme Afterlight \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
  test CODE_SIGNING_ALLOWED=NO
```

Unit tests cover purchases, upgrade caps, persistence, campaign progression, daily rewards, circuit closure, race completion, pausing, nitro, drift, and off-road behavior. The UI journey covers home, garage, story, world map, a complete race, pause/resume, results, and settings. UI attachments capture actual app screens.

## Release

Bundle ID: `com.oanarinaldi.Turbo-Racer` (the existing app). Team: `HBD3XXQK45`. App Store Connect app ID: `6478083613`. Version 2.0.0, build 5.

Use `release/ExportOptions.plist` for App Store export; archives and signing products are intentionally excluded from Git. Release metadata and validation notes live in `release/`.

## Ownership and data

All car names and track geometry are original fictional designs. Geometry, environments, and score are produced by project code. Cover and icon were generated with OpenAI ImageGen for this project; there are no downloaded car models, licensed vehicle badges, or third-party music samples. The score can be regenerated with `python3 Afterlight/Tools/compose_soundtrack.py`.

The app uses UserDefaults for on-device saves with required reason CA92.1 declared in its privacy manifest. Players can reset progress from Settings. Website privacy policy: https://oanarinaldi.com/turboracerprivacy.html.
