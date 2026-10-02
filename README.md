# Afterlight: Racing Festival

A native offline arcade racing adventure for iPhone and iPad. The original 2024 Unity export remains at the repository root as an archive. Active development is in **Afterlight/**; no Unity installation is required.

## Play

Inherit your father's Solstice, rebuild the garage with mechanic Mika, and join the Afterlight Festival. Race from Palm Coast through Neon Harbor and Ember Canyon to Cloudline. Earn five campaign stars in each region to open the next.

- Four themed districts with five separately authored routes each. Every route now has a setting-specific landmark complex, ground treatment, lighting profile and scenery density; shared district assets remain. Constant-width roads and arc-length sampling keep corner widths and driving speed consistent.
- Twenty original 3D circuits with UV-mapped asphalt, normal/roughness maps, guardrails, textured terrain, coastal landscaping, detailed licensed city buildings, scanned cliffs and alpine trees. HDR skies, metallic reflections, shadows and chase-camera framing.
- Sixty campaign events: two-lap races with three rivals, time attack, and drift runs.
- Six fictional garage entries. The local licensed art build replaces SOLSTICE with an independent luxury sedan and KOMET with an independent sports coupe; VANTA uses an independent concept GT; the remaining three entries use concept-platform derivatives. Authored interior, alloy wheels, tread normals and brake hardware; wheels rotate during racing.
- Automatic acceleration, touch steering, braking, drift combos, nitro, off-road penalties, and rival collisions with model-sized body volumes and swept contact checks. The rival roster excludes the player’s body family and uses three different families. Nitro eases the chase camera in and out, and an exhausted tank stays off until the button is released. The simulation clock runs during touch tracking.
- Twelve metallic memory chips per circuit: collect them to recharge nitro, earn credits, and recover four notebook pages through district-wide progress. A live route map tracks your race position.
- Daily rotating drift challenge; the first starred run awards 350 extra credits.
- Persistent garage, best times, drift records, stars, statistics, and milestones.
- Landscape racing and landscape menus, with a full-screen industrial car showroom, blue service bay, cyan telemetry and yellow actions, side navigation and thumb controls at the lower corners.
- Original generated cover/icon/asphalt art and a reproducible synth score. Bundled CC0 HDR lighting. No ads, purchases, accounts, analytics, or external game services.

## Build

Run `Afterlight/Tools/generate_project.sh`, then open `Afterlight/Afterlight.xcodeproj` in Xcode. Select the **Afterlight** scheme and a simulator or signing-enabled iOS device. Deployment target: iOS 17.

The committed Xcode project is generated from `Afterlight/project.yml`. When changing project structure, run:

```sh
Afterlight/Tools/generate_project.sh
```

## Verify

```sh
xcodebuild -project Afterlight/Afterlight.xcodeproj -scheme Afterlight \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
  test CODE_SIGNING_ALLOWED=NO
```

Camera-space steering regression and UI touch checks cover both landscape orientations. Unit tests cover route landmark clearance, purchases, upgrade caps, persistence, campaign progression, daily rewards, circuit closure, race completion, pausing, nitro, drift, and off-road behavior. The UI journey covers home, garage, story, world map, a complete race, pause/resume, results, and settings. UI attachments capture actual app screens.

## Release

Bundle ID: `com.oanarinaldi.afterlight`. Team: `HBD3XXQK45`. App Store Connect app ID: `6818519420`. Version 1.0.0, build 20. The separate app identity was requested by the owner; the original Turbo Racer record and its saves remain untouched. The new installation uses its own save container. See `release/SubmissionStrategy.md` for submission status and `release/Validation.md` for the test evidence.

Use `release/ExportOptions.plist` for App Store export; archives and signing products are intentionally excluded from Git. Release metadata and validation notes live in `release/`.

## Ownership and data

Car names and circuits are fictional. The concept vehicle is by Eric Chadwick / Darmstadt Graphics Group, licensed CC BY 4.0. Coastal palm geometry is by Wolfgang Wozniak, CC BY 3.0, with a generated replacement atlas. Scanned cliffs, trees and HDR environments are CC0 Poly Haven assets. Detailed city architecture is from Quaternius’ CC0 Downtown City MegaKit Standard. See the bundled `Afterlight/Resources/AssetCredits.txt` and in-game Settings for full attribution. All runtime assets are bundled for offline play.

The score can be regenerated with `python3 Afterlight/Tools/compose_soundtrack.py`. Material maps use `Afterlight/Tools/compose_materials.py` (Python, NumPy, Pillow). Car derivatives use Blender with `Afterlight/Tools/design_fleet.py`. Environment and city conversion scripts are in `Afterlight/Tools/`. Source model attribution and derivative changes are recorded in the bundled credits.

The app uses UserDefaults for on-device saves with required reason CA92.1 declared in its privacy manifest. Players can reset progress from Settings. Website privacy policy: https://oanarinaldi.com/afterlightprivacy.html.

## Local licensed art

BlenderKit Royalty Free models are local build inputs and are deliberately excluded from public Git. The sedan and coupe are designs by Pierre-Louis Baril; Vanta GT is adapted from Sharif Miah’s Concept styled sports car 1; the coconut palm is by Jan Hecl, warehouse by Dennis Hafemann and five city buildings by Alex Samusenko. See bundled AssetCredits.txt for source links. Public checkouts fall back to the bundled concept cars, coastal palm, original showroom and Quaternius architecture.

Convert the downloaded GT using `prepare_concept_gt.py`. Convert other legitimately downloaded Blender sources using `prepare_licensed_sedan.py` (optional second argument `SportsCoupe` or `RivalPickup`) and `prepare_licensed_palm.py`. These write to the local ArtSources directory. `prepare_licensed_garage.py` and `prepare_licensed_city.py` take the downloaded source and a private output path; they bake facade/color and normal atlases for the native renderer. Package each GLB with `swift Afterlight/Tools/pack_art.swift <source.glb> Afterlight/Resources/Protected/<name>.asset Afterlight/Sources/GeneratedArtKeys.swift`, then regenerate the project. The packer preserves keys in a private manifest outside the repository. Never publish source models, protected packs or generated keys.

The app decrypts AES-GCM packs in memory. This avoids distributing plainly extractable source files; it is not a claim of tamper-proof protection. Assets remain subject to the provider's license.
