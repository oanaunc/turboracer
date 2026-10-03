# Afterlight — upgrade plan toward an Asphalt 8–class presentation

3 October 2026. Starting point: version 1.0.0 (20), Waiting for Review. Native SwiftUI + SceneKit, twenty routes, six cars across four body families, procedural audio.

Asphalt 8 is the product of a large studio with licensed manufacturers. Afterlight cannot use real car brands and remains a native SceneKit game, so the goal is the same *feel*: speed, light, spectacle, a desirable garage and punchy sound. Each phase ships as its own build, is tested on Oana's iPhone 17 Pro Max, and is committed and pushed in small steps.

## Phase 1 — Speed and light (code only, no new licenses)

Biggest visible gain per hour of work.

- Car paint: clear-coat PBR layer, flake normal, tuned environment reflections per district; glass with real reflectance; emissive tail/head lamps with bloom.
- Post-processing per district: color grading, stronger tuned bloom, vignette, speed-scaled motion blur and field-of-view kick on nitro.
- Effects: nitro exhaust flames and heat streaks, tyre smoke while drifting, persistent skid marks, sparks on barrier and rival contact, speed lines, camera shake on impacts and landings.
- Lighting: sun shadow cascades tuned to the chase camera, night routes with lit street lamps and car light cones.
- Performance guard: keep 60 fps on iPhone 17 Pro Max with a quality tier for older devices.

## Phase 2 — Sound

- Engine built from layered idle/low/high loops cross-faded by RPM, with gear shifts and turbo/blow-off; separate character per body family.
- Tyre squeal tied to drift angle, nitro ignition and whoosh, impacts, wind at speed, chip pickup, UI clicks, countdown and finish stingers.
- Sources: CC0 packs (Kenney, Freesound CC0, Sonniss GDC bundles) plus synthesis; every file recorded in AssetCredits.txt.
- Music: one energetic track per district plus menu theme. Either regenerated with the existing synth tool, or Suno if Oana approves (see "Needs Oana").

## Phase 3 — Cars and garage

- Higher-detail fictional cars from properly licensed free sources (Sketchfab CC0/CC BY, Poly Pizza, Quaternius), cleaned in Blender, to give six distinct body families instead of three platform derivatives. No real brands or badges.
- Customisation: paint (metallic, matte, pearl), rims, liveries/decals, underglow; stat changes visible per upgrade stage.
- Showroom: turntable camera with orbit gesture, lights sweeping the paint, unlock and purchase reveal animation.

## Phase 4 — Tracks and gameplay spectacle

- Track furniture that gives Asphalt its energy: ramps and jumps, tunnels, bridges, shortcuts, grandstands with crowds, banners, gantries, arrow boards, night neon.
- Gameplay: knockdowns of rivals, perfect-nitro timing, barrel-roll jumps, larger grid (up to 6 rivals), lap and position call-outs.
- Scenery density pass per district so routes stop repeating, with vegetation and distant skyline layers.

## Phase 5 — Interface

- Concept-led redesign: animated main menu over a live 3D scene, card-based career map per district, car cards with class/rank, podium results screen with replays of the finish, loading screens with art.
- HUD: arc speedometer, position badge, nitro gauge with tiers, cleaner mini-map, haptics on shifts and impacts.
- Concept art from ChatGPT/Midjourney (if approved) is used as reference; in-game art is rebuilt natively.

## Phase 6 — Release

- Full test suite, iPhone and iPad device runs, sustained full-lap frame-rate checks.
- New App Store screenshots and preview from real gameplay; description and What's New; privacy policy from `~/Desktop/oanarina_website` checked against the app.
- Submission only after Oana confirms. Build 20 is currently in review; uploading a replacement means removing build 20 from review and submitting the new build.

## Needs Oana

1. Paid/signed-in tools. Suno songs made on the free plan cannot be used commercially, and Midjourney requires a paid plan; ChatGPT images and Higgsfield credits use the account owner's balance. These are only used with explicit approval.
2. App Store submission at the end.

## Asset rules

Only CC0, CC BY (credited) or royalty-free licenses that allow commercial use in an app. Every asset is listed in `Afterlight/Resources/AssetCredits.txt` with author, URL and license.
