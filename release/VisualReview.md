# Development build 9 — reference-driven racing redesign

2 October 2026. App Store submission remains on hold. The user's seven supplied references establish industrial garages, large contemporary vehicles, cyan performance telemetry, yellow actions and detailed street scenes. See ArtDirection.md.

## Changes

The native GLB loader preserves authored geometry, normals, UVs, hierarchy and PBR maps. Three Blender-authored mesh derivatives of the credited concept platform add compact coupe, lower/wider hypercar and open roadster silhouettes. The fleet still shares one source platform; it is not six independent manufacturer models.

The garage is a 3D architectural room with tiled flooring, structural beams, ceiling light panels, façade glazing, wall fixtures and signage. Performance information overlays the wide 3D scene. Compact segmented cyan bars, yellow selection actions and car switching follow the supplied references.

The city uses Quaternius' CC0 Downtown City MegaKit Standard buildings with brickwork, entrances, windows, stairs and rooftop details. Their façades face the road. Imported scenery remains in its authored scene hierarchy: flattening the entire world had hidden those assets. Coast and alpine import credited palm, scanned cliff and tree meshes. Roads use continuous textured geometry; the camera follows heading without falling behind as speed rises.

## Validation and remaining work

Ten unit tests pass in /tmp/AfterlightArt8/Logs/Test, including body silhouette differences, all environment imports, progression and driving effects. The six-car/four-region UI journey passed after the scenery hierarchy fix, including a minimum 30 fps simulator assertion. Its xcodebuild result finalization stalled, so it is not a complete release validation bundle. Direct simulator screenshots verify that imported city façades and landscaping now render.

Build 8 was installed successfully. Physical build 9 checks require the connected phone to be unlocked. The game still needs further visual polish, especially lighting, landscaping, road furniture and consistent artwork across the calendar and journal. No claim of Asphalt-equivalent visual quality or final release readiness is made.

## Rights

Vehicle derivatives: DGG / Eric Chadwick, CC BY 4.0. Palm: Wolfgang Wozniak, CC BY 3.0. Quaternius city architecture and Poly Haven environments: CC0. Original generated texture art and original code, circuits, story and synthesized audio. Full attribution is bundled in Settings. Reference screenshots are not runtime assets and are excluded from Git.

Roadside rock fix: imported cliff footprints are capped at 18 metres, positioned 38 metres from the reference line, and rejected if they fail clearance from any of 480 road samples. Distant and shoreline cliff widths are also capped. A regression test checks actual transformed bounds against the full canyon and alpine circuits.
