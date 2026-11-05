# Afterlight: Racing Festival — Android release, November 5, 2026

Prepared locally for Google Play; **not submitted**. The new-app form is open with English (US), free game, title **Afterlight: Racing Festival** and package **com.oanarinaldi.afterlight**. Google confirmed package availability. The developer-policy and US export certifications remain unchecked for the owner to review. No Play app ID or review-submission ID has been created.

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

## Store setup prepared

The English listing is in `listing-en-US.json`, with free Racing classification, no real-money purchases, support contact `oanarinaldi@gmail.com` and the published privacy policy. Age-rating and target-audience questionnaires still need to be completed after app creation; no ratings have been asserted or submitted.

The shared privacy policy now covers Android storage, Google Play install-time artwork and disabled Android backup. Website main commit `996bd0d` was pushed and the live page verified:

https://oanarinaldi.com/afterlightprivacy.html

See `android/README.md` for reproduction, signing and asset-pack instructions. The production base APK alone omits the licensed scenery; install the complete bundle/APK set.
