# Development build 17 — nitro stability and a varied rival grid

The nitro camera now eases its distance and lens instead of snapping. A held, exhausted tank no longer alternates boost on/off as tiny amounts of fuel regenerate. The simulation uses a display-linked clock in common run-loop modes, and scene updates explicitly disable implicit animation.

Rival selection excludes the player’s entire body family. In the recorded Solstice race, the opponents are Komet, Vanta and Aurora, each retaining its collider and authored wheel pivots. The roster varies by route and player selection. This changes the lineup rather than adding new car assets.

The camera/fuel regressions, all six player selections across twenty rosters, repeated touch holds, both landscape steering orientations and a complete race journey passed. See Validation.md for the measured simulator timing and physical-device limitation. Build 17 is installed; device nitro playtesting is pending unlock.

---

# Development build 16 — steering and route identities

The LEFT/RIGHT reversal is corrected in the physics-to-camera conversion. Actual touch-button tests passed in both landscape orientations; camera-space regression checks both displacement and vehicle yaw. See build 15 evidence in Validation.md.

Build 14 supplied twenty road layouts inside four shared environment families. Build 16 gives each route its own setting profile and landmark complex, with ground, lighting, silhouette and scenery-density variations. These remain shared-region scenes with native procedural landmarks, not twenty fully bespoke high-fidelity environments. ArtDirection.md lists each route’s setting.

Landmark placement reserves the complete horizontal footprint against the full circuit. Terrain levels under those footprints; buildings, rocks and foliage avoid them. The procedural primitives retain their node hierarchy: SceneKit flattening returned empty bounds in the initial attempt, which the new landmark validation caught. The corrected hierarchy passed all placement checks. The canyon arch was refined after an initial render review.

Validation completed:

- All 19 unit tests passed, including steering, progression, collisions, route clearance, district art identity and all sixty landmark sites.
- The twenty-route capture sweep completed with TEST SUCCEEDED, with every route passing a 30 fps minimum simulator sample. This is not a physical-device performance claim.
- After the final canyon mesh change, all 19 unit tests, canyon grid/racing captures and the complete race/results/next-event journey passed in a completed final invocation.
- Device build 2.0.0 (16) compiled and installed on Oana’s iPhone. Automated launch was blocked by iOS reporting the phone locked; launch and sustained physical play remain user checks. Existing saves were preserved.

Evidence: `/tmp/afterlight16-verified.log`, `/tmp/afterlight16-final.log`, `/tmp/afterlight16-phone-final.log`, `/tmp/afterlight16-install.log`, `/tmp/afterlight16-launch.log`. Representative actual simulator captures are in `release/screenshots-build16/`.

The new settings make route identity more visible, but scenery density, landmark fidelity, terrain transitions, foliage, facade texture resolution and overall lighting remain below the requested Asphalt reference. App Store submission stays on hold. No new data collection or external services were added.

---

# Development build 14 — World Tour and full-screen Motorworks

2 October 2026. App Store submission remains on hold for further artistic and physical-device review.

## Implemented

- Twenty individually authored closed routes, arranged as five routes per district. Four environment themes, sixty circuit/time-attack/drift events and 180 available stars. The original four circuit IDs remain stable for existing saves. Five stars earned anywhere in a district unlock the next district; daily events do not bypass this progression.
- Arc-length sampling gives consistent speed along each route. Lane coordinates are now perpendicular metres, so corners preserve road width and full-body barriers remain valid. Route tests check closure, spacing, lane width and self-clearance.
- World Tour district tabs, route diagrams, route character, distance, star totals and explicit locked states. The notebook remains four chapters, with memories aggregated across each district’s five routes; daily rotation now includes all twenty routes. A live route map tracks the player in the race HUD.
- VANTA uses Sharif Miah's independently modeled Concept styled sports car 1, with native PBR materials and four rotating wheel assemblies. It also replaces the pickup on the rival grid. SOLSTICE and KOMET keep their independent Pierre-Louis Baril meshes with more exterior geometry and transferred authored surface normals. Three later garage entries still derive from the original DGG platform; the fleet is not six independent meshes.
- The Motorworks showroom fills the landscape screen behind the HUD. A deep blue service bay, yellow pit markings and cyan pit-wall branding replace the unbroken grey floor around the car.
- Coastal settlement density increased, architecture placed on level urban/coastal terrain, and imported open basement geometry buried into sealed low foundations. Complete-model road clearance remains enforced, including entrance stairs. Coastal buildings are excluded from the sea side of the terrain boundary.
- CC0 scanned grass/rock diffuse, normal and roughness maps from Poly Haven, with downloaded checksums verified. Distant terrain uses grounded hills instead of flattened cliff silhouettes. Slim cantilever LED street lamps replace the glowing spheres.

## Validation

The final selected test run completed with **TEST SUCCEEDED**: 17 unit tests and two UI cases covering all twenty calendar routes, all six garage entries and four environment renders. Unit coverage includes district save migration and memory aggregation, right-handed steering coordinates, full-circuit scenery clearance, sealed building foundations, body barriers and eleven private art packs. The final region snapshots each recorded 60 fps in the simulator.

The complete race/results/next-event journey and rival-grid case also passed during this build’s earlier broad art run; the rival grid recorded 56.7 fps in the simulator. That invocation failed only because the new calendar test omitted dismissing the first-race briefing. The test was fixed and passed in the final run. An intermediate regression invocation reported all cases passed but stalled finalizing its result bundle and was canceled; it is not counted as a completed successful command. The separate iPad layout run completed with TEST SUCCEEDED.

The final device build succeeded, installed as version 2.0.0 (14), and devicectl confirmed launch on Oana’s iPhone. Existing user saves were preserved. Installation and launch do not establish sustained physical-device performance; simulator frame rates are not device measurements.

Logs: `/tmp/afterlight14-verified.log`, `/tmp/afterlight14-final-tests.log`, `/tmp/afterlight14-tablet.log`, `/tmp/afterlight14-phone-final.log`, `/tmp/afterlight14-install.log`, `/tmp/afterlight14-launch.log`. Final native simulator captures are saved in `release/screenshots-build14/`.

## Asset handling and limits

Licensed BlenderKit sources, plaintext derivatives, encrypted local packs and generated keys remain excluded from public Git. Public builds use the credited fallback art. AssetCredits.txt includes exact provenance; prepare_concept_gt.py and the updated sedan converter make the private adaptations reproducible.

The visual references guide the composition, motorsport colors and vehicle prominence. This remains an arcade racing development build; it is not an Asphalt-quality claim or a final art sign-off. Remaining work includes higher fidelity track dressing, vegetation, distant scenery, lighting and sustained physical-device performance review.

<details>
<summary>Build 13 review history</summary>

# Development build 13 — industrial garage and varied city architecture

2 October 2026. App Store submission remains on hold. The seven supplied references establish large contemporary vehicles, industrial garages, cyan telemetry, yellow actions and detailed street scenes. Vehicle surface polish, lighting, terrain silhouettes and remaining menu art still need further work; this is not a final visual sign-off.

## Vehicles and landscaping

The local licensed build now uses Pierre-Louis Baril's independent Generic Sport Sedan 2022 PL for SOLSTICE and Generic Sportscar PL for KOMET. The rival grid uses that coupe, the sedan and the author's Jotun pickup. The other garage entries remain concept-platform derivatives; the fleet is not six independent models. Author geometry is evaluated in Blender, adapted to mobile PBR materials and consolidated into body/four wheel assemblies. Authored wheel pivots rotate in races.

Jan Hecl's coconut palm replaces the coastal placeholder in the local build. Conversion preserves bark and foliage maps with explicit alpha cutouts. UV layer names are normalized before joining the authored parts; otherwise leaf parts inherited empty UV coordinates. The native GLB loader uses the correct UIImage texture orientation and respects alpha cutoff.

BlenderKit Royalty Free source files, runtime packs and generated encryption keys stay outside public Git. App packs use AES-GCM and decrypt in memory. This avoids plainly extractable GLB files, without claiming unbreakable protection. Public source checkouts regenerate their project using Tools/generate_project.sh and use the credited bundled fallback art. AssetCredits.txt records exact authors, source pages and licenses.

## Garage and city art

Dennis Hafemann's Industrial Old Warehouse replaces the enclosed tile showroom in the local build. Its concrete color/normal atlas is baked at 2048px; authored windows and shutter geometry are retained, loose debris and atmosphere removed, and the bay enlarged for the fleet. Suspended light rails, yellow bay markings, cyan accents and tool cabinets establish the Motorworks setting. The camera avoids the front pillar and places the hero car beside a narrower performance panel. HDR/spot lighting is reduced to improve paint highlights.

Five meshes from Alex Samusenko's City Scene add a bank, office, terrace, brick building and apartment block. Each uses a private 1024px facade/normal atlas and portable glazing. Complete city geometry is not bundled. These buildings also replace the simple coastal villas when the local packs are available. Brown coastal tree placeholders are removed. White road paint, concrete curbs and pavement now follow continuous circuit ribbons instead of glowing rectangular segments that separated on bends.

## Gameplay fixes

The landscape results overlay has visible return and next-event buttons without scrolling. Choosing the next event opens the calendar; five campaign stars unlock the next region. The introductory briefing appears only before the first race. Preview and journey checks use isolated saves.

All player/rival cars have model-sized kinematic body shapes. The arcade controller resolves swept body contact, including finish-line wrapping and the increased lateral reach during drifting. Impact cooldown limits speed penalties and feedback, never contact detection. Contact separates cars laterally and reduces speed. The continuous safety boundary also accounts for the whole player body on distorted curves; sustained rail scraping cannot compound penalties into a permanent stop. This is arcade body contact, not a rigid-body damage simulation.

Imported city buildings are placed using their complete transformed bounds, including stairs, and rejected unless the whole circuit remains clear. Rock placement retains the full-circuit clearance rule.

## Validation

Fourteen unit tests passed with all ten local licensed packs present, including decryption, wheel pivots, body contact, driving effects, progression and complete-circuit scenery clearance. The clearance case now includes the coast. The six-car/four-region visual case passed its minimum 30 fps simulator checks in 64.824 seconds. Earlier first/second-race navigation and complete rival-grid checks remain recorded for build 11; those flows were not changed in this art pass.

Logs: /tmp/afterlight-city13-final-tests.log, /tmp/afterlight-city13-final-phone.log and /tmp/afterlight-city13-final-install.log. Physical build 13 compiled and installed on Oana's iPhone. Physical launch/performance verification remains pending because iOS reports the phone locked. Simulator timing is not a physical-device frame-rate claim. Native render evidence: /tmp/afterlight-garage12-final.png and subsequent build 13 city/coast screenshots.

## Remaining art work

The garage and architecture have improved, but vehicle surface fidelity, terrain silhouettes, lighting, distant scenery and remaining menu art still need further refinement against the supplied references. Further professional art work and physical-device performance review are required before App Store submission.

</details>
