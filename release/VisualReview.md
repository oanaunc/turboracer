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
