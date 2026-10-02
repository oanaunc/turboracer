# TurboRacer: Afterlight

A native offline arcade racing adventure for iPhone and iPad. The original 2024 Unity export remains at the repository root as an archive. Active development is in **Afterlight/**; no Unity installation is required.

## Play

Inherit your father's Solstice, rebuild the garage with mechanic Mika, and join the Afterlight Festival. Race from Palm Coast through Neon Harbor and Ember Canyon to Cloudline. Earn five campaign stars in each region to open the next.

- Four original 3D circuits with UV-mapped asphalt, normal/roughness maps, guardrails, textured terrain, coastal landscaping, detailed licensed city buildings, scanned cliffs and alpine trees. HDR skies, metallic reflections, shadows and chase-camera framing.
- Twelve campaign events: two-lap races with three rivals, time attack, and drift runs.
- Six fictional performance variants of a licensed contemporary concept platform, including authored Sprint, Hyper and Roadster body geometry, paint and track aero. Authored interior, alloy wheels, tread normals and brake hardware; wheels rotate during racing.
- Automatic acceleration, touch steering, braking, drift combos, nitro, off-road penalties, and rival collisions.
- Twelve memory sparks per circuit: collect them to recharge nitro, earn credits, and recover four notebook pages in the story journal.
- Daily rotating drift challenge; the first starred run awards 350 extra credits.
- Persistent garage, best times, drift records, stars, statistics, and milestones.
- Landscape racing and landscape menus, with an industrial car showroom with cyan telemetry and yellow actions, side navigation and thumb controls at the lower corners.
- Original generated cover/icon/asphalt art and a reproducible synth score. Bundled CC0 HDR lighting. No ads, purchases, accounts, analytics, or external game services.

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

Bundle ID: `com.oanarinaldi.Turbo-Racer` (the existing app). Team: `HBD3XXQK45`. App Store Connect app ID: `6478083613`. Version 2.0.0, development build 9. App Store submission is held while the visual/product redesign is reviewed.

Use `release/ExportOptions.plist` for App Store export; archives and signing products are intentionally excluded from Git. Release metadata and validation notes live in `release/`.

## Ownership and data

Car names and circuits are fictional. The concept vehicle is by Eric Chadwick / Darmstadt Graphics Group, licensed CC BY 4.0. Coastal palm geometry is by Wolfgang Wozniak, CC BY 3.0, with a generated replacement atlas. Scanned cliffs, trees and HDR environments are CC0 Poly Haven assets. Detailed city architecture is from Quaternius’ CC0 Downtown City MegaKit Standard. See the bundled `Afterlight/Resources/AssetCredits.txt` and in-game Settings for full attribution. All runtime assets are bundled for offline play.

The score can be regenerated with `python3 Afterlight/Tools/compose_soundtrack.py`. Material maps use `Afterlight/Tools/compose_materials.py` (Python, NumPy, Pillow). Car derivatives use Blender with `Afterlight/Tools/design_fleet.py`. Environment and city conversion scripts are in `Afterlight/Tools/`. Source model attribution and derivative changes are recorded in the bundled credits.

The app uses UserDefaults for on-device saves with required reason CA92.1 declared in its privacy manifest. Players can reset progress from Settings. Website privacy policy: https://oanarinaldi.com/turboracerprivacy.html.
