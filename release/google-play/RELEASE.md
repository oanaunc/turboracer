# Afterlight: Racing Festival — Android release, November 6, 2026

**Submitted to Google Play production review on November 6, 2026.** Play Console shows [submission 1 in review](https://play.google.com/console/u/0/developers/8359156760975569195/app/4974962365827548181/publishing/submission-activity/1/details). The Play app ID is `4974962365827548181`, package `com.oanarinaldi.afterlight`, and release `Afterlight 1.0.0 (1)`. Managed publishing is off. The full rollout is configured for 177 listed countries and regions plus the rest of the world, subject to Google's approval and availability.

## Build and content

Version 1.0.0 (1), Android 10+ / API 29, target API 36. The signed AAB and its SHA-256 and source fingerprint are recorded in `build-info.json`. Private upload signing configuration is outside Git at `~/.local/share/afterlight/android-upload/`; private scene encryption inputs are outside Git as well.

The port includes the shipping Apple catalogue: twelve cars, twenty authored circuits, eighty campaign events, six race modes, all four story and notebook chapters, daily challenges, milestones, credits and upgrades, stunts, ramps, takedowns, shockwave nitro, original Suno tracks and WAV effects. The engine synthesizer follows the Apple sample-generation signal path.

The opt-in iOS exporter preserves the actual licensed geometry, transforms, material maps, native car collision bounds, route samples and static sign outlines. SceneKit GPU-only flattened nodes are exported through their original hierarchy. Procedural primitives retain their dimensions. The landscape and animated sea shaders are translated from the Apple source.

The `festival_art` module is delivered at install time through Play Asset Delivery, so the complete scenery is available offline at first launch. Its generated manifest is saved as `festival-art-manifest.xml`. The base application has no Internet permission, ads, billing, login, analytics or developer backend. Native Android handles lifecycle pausing, local saves, tilt steering, haptics and system Back. Android cloud backup is disabled.

## Validation

- Ten gameplay test groups pass: complete catalogue and stable event IDs; all twenty closed routes and their width/sampling against actual Apple exports; purchases and upgrade limits; campaign and UTC daily rewards; malformed-save validation; distinct rival families; steering/braking/pause/nitro; scoring, collection and all six result rules; ramps/barrel rolls and swept collisions; deterministic completion of time attacks on all twenty routes.
- The opt-in iOS export passed for all twelve cars, the showroom and all twenty circuit scenes. All 36,769 exported geometries have mesh data or explicit primitive definitions; static labels use native outlines rather than empty GPU text meshes.
- Instrumented Android journeys passed on API 36 in phone and tablet layouts. They exercise fresh-game briefing, actual held touch steering/nitro, racing, pause/resume, results and earned credits, settings, five routes per district in the calendar, all four story chapters, four rendered districts and save/reward restoration after activity recreation. Captures wait for rendered frames and assert zero scene shader compilation errors.
- Release compilation, release lint and signed-bundle validation passed. The upload-signed production APK set was installed with its base, language, density and `festival_art` splits; the production app launched and rendered its licensed showroom and car. `qa/production-installed-home.png` records that launch. `bundle-validation.json` and the dumped manifests describe the signed production bundle, API levels, absence of Internet/advertising-ID permissions, non-debuggable release and install-time art split.
- Store assets come from actual Android captures in `qa/`; the icon comes from the original Apple icon. Console approval screenshots are kept locally, outside Git.

## Visual limits

The original models, scene composition, artwork, catalogue and UI dimensions are preserved. This is a separate WebGL/Android implementation. Roboto Condensed and original SVG controls replace Apple's licensed system font and symbols; rendering, tone mapping, shadows, bloom, color fringing and platform controls are not pixel-identical to SceneKit/SwiftUI. Textures are capped at 2048px for mobile memory. No automated pixel-equivalence claim is made. Physical Android hardware, motion-sensor behavior and live Google Play installation/protection have not been validated by emulator testing alone.

## Store submission

The English (US) listing uses `listing-en-US.json`, the original icon, the feature graphic, and six actual screenshots each for phones and 10-inch tablets. The icon and Crew images carry Google Play's AI artwork disclosure. The game is free in Racing with no purchases, ads, accounts, advertising ID or app data collection. The target audience starts at age 13. The IARC questionnaire discloses vehicle takedowns without blood, gore, or violence depicted against people or animals; the resulting European rating is PEGI 7. Developer-policy, US export and IARC terms were authorized by the owner.

The shared privacy policy now covers Android storage, Google Play install-time artwork and disabled Android backup. Website main commit `996bd0d` was pushed and the live page verified:

https://oanarinaldi.com/afterlightprivacy.html

See `android/README.md` for reproduction, signing and asset-pack instructions. The production base APK alone omits the licensed scenery; install the complete bundle/APK set.
