# Development build 11 — authored vehicles and body contact

2 October 2026. App Store submission remains on hold. The seven supplied references establish large contemporary vehicles, industrial garages, cyan telemetry, yellow actions and detailed street scenes. Overall lighting, scenery density, coastal architecture and menu art still need further work; this is not a final visual sign-off.

## Vehicles and landscaping

The local licensed build now uses Pierre-Louis Baril's independent Generic Sport Sedan 2022 PL for SOLSTICE and Generic Sportscar PL for KOMET. The rival grid uses that coupe, the sedan and the author's Jotun pickup. The other garage entries remain concept-platform derivatives; the fleet is not six independent models. Author geometry is evaluated in Blender, adapted to mobile PBR materials and consolidated into body/four wheel assemblies. Authored wheel pivots rotate in races.

Jan Hecl's coconut palm replaces the coastal placeholder in the local build. Conversion preserves bark and foliage maps with explicit alpha cutouts. UV layer names are normalized before joining the authored parts; otherwise leaf parts inherited empty UV coordinates. The native GLB loader uses the correct UIImage texture orientation and respects alpha cutoff.

BlenderKit Royalty Free source files, runtime packs and generated encryption keys stay outside public Git. App packs use AES-GCM and decrypt in memory. This avoids plainly extractable GLB files, without claiming unbreakable protection. Public source checkouts regenerate their project using Tools/generate_project.sh and use the credited bundled fallback art. AssetCredits.txt records exact authors, source pages and licenses.

## Gameplay fixes

The landscape results overlay has visible return and next-event buttons without scrolling. Choosing the next event opens the calendar; five campaign stars unlock the next region. The introductory briefing appears only before the first race. Preview and journey checks use isolated saves.

All player/rival cars have model-sized kinematic body shapes. The arcade controller resolves swept body contact, including finish-line wrapping and the increased lateral reach during drifting. Impact cooldown limits speed penalties and feedback, never contact detection. Contact separates cars laterally and reduces speed. The continuous safety boundary also accounts for the whole player body on distorted curves; sustained rail scraping cannot compound penalties into a permanent stop. This is arcade body contact, not a rigid-body damage simulation.

Imported city buildings are placed using their complete transformed bounds, including stairs, and rejected unless the whole circuit remains clear. Rock placement retains the full-circuit clearance rule.

## Validation

Fourteen unit tests passed with all four local licensed packs present: decoding, wheel pivots, body colliders, swept contact, real rival contact, road clearance, purchases, persistence, progression and driving effects. Two UI cases passed: completing the first race and starting another event, and rendering the complete licensed rival grid with a minimum 30 fps simulator assertion. The separate six-car/four-region visual case also passed its 30 fps checks.

Logs: /tmp/afterlight-final-barrier-tests.log, /tmp/afterlight-build11-final-tests.log and /tmp/afterlight-licensed-fleet-visual-test.log. Xcode's result-bundle finalization has previously stalled on this host; case-level success is reported separately from a completed result bundle. Physical build 11 compiled and installed on Oana's iPhone. Launch/performance verification needs the phone unlocked; iOS denied the initial launch because it was locked.

## Remaining art work

Garage architecture, coastal buildings, terrain silhouettes, road furniture and lighting still do not match the supplied references. Further professional art work and physical-device performance review are required before App Store submission.
