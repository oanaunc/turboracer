# Racing art direction

The user's seven images in `car games ui examples` are visual references only and are excluded from distribution. They establish a landscape arcade racer with a full scene behind the garage interface, large contemporary sports cars, industrial blue lighting, compact cyan performance bars and yellow action buttons. City races need detailed façades, sidewalks, street lighting and atmosphere, rather than repeated untextured towers.

Solstice uses Pierre-Louis Baril's fictional luxury sport sedan; Komet uses his independently modeled sports coupe. Vanta uses Sharif Miah’s independently modeled Concept styled sports car 1, adapted into a two-tone GT. Competitors use the coupe, sedan and GT, each with a body-sized collider and four authored wheel pivots. The other three selectable cars retain the DGG concept platform and authored Hyper/Roadster variants; they are not three additional independently sourced models.

The garage adapts Dennis Hafemann's Industrial Old Warehouse with a baked concrete atlas, suspended fixtures, a deep blue epoxy service bay, yellow pit markings, cyan accents and tool cabinets. The scene fills the landscape screen behind compact telemetry panels and the vehicle selector. Jan Hecl's palm replaces the earlier coastal palm. BlenderKit Royalty Free sources and plaintext exports remain private; encrypted local packs are decoded in memory. A public checkout without those local packs uses the original fallback art.

Five buildings adapted from Alex Samusenko's City Scene now provide varied native architecture for the night city and coastal promenade. Their mobile facade and normal atlases preserve surface detail, and placement checks use complete transformed bounds. Road edges and pavement follow continuous circuit ribbons. The free Quaternius Downtown City MegaKit Standard provides fallback modular architecture. Licensed source attribution is in the app's Art credits. Visual quality requires direct render review, followed by physical iPhone performance checks; build success alone does not establish artistic acceptance.

World Tour groups twenty individually authored routes into Riviera, Night City, Badlands and Alpine districts. Compact route diagrams, distance, route character and three event buttons make each route selectable in landscape. In-race navigation uses a live route map. Urban and coastal terrain is level, imported basements sit below sealed low foundations, and stairs remain outside the full road clearance envelope. Poly Haven’s CC0 Aerial Grass Rock maps add scanned ground detail. Slim LED lamps and lower coastal hills improve the roadside silhouette. Remaining visual priorities are richer vegetation, coherent streetscape dressing, facade fidelity and lighting.


## Route-specific scenery pass — build 16

The four district asset families are still shared. Build 14 had twenty road shapes but did not have twenty different environments. Build 16 adds a distinct setting, native landmark complex, terrain surface, lighting temperature and vegetation/building density for each route. This is an initial scene differentiation pass, not twenty bespoke production-quality worlds.

| Route | Setting |
| --- | --- |
| Palm Coast | Palm resort with balcony wings |
| Azure Run | Beach club, shaded terraces and loungers |
| Marina Loop | Sailing basin, docks and moored yachts |
| Riviera GP | Grandstands and festival paddock |
| Sunset Point | Lighthouse headland |
| Neon Harbor | Illuminated waterfront plaza |
| Docklands | Container stacks and gantry cranes |
| Old Quarter | Low-rise square and fountain |
| Metropolis | Glass office skyline |
| Nightshift | Silos and industrial works |
| Ember Canyon | Sandstone arches |
| Redline Mesa | Wind farm |
| Devil’s Elbow | Terraced quarry |
| Dust Trail | Desert service station |
| Copper Ridge | Observatory and solar arrays |
| Cloudline | Forest lodges |
| Sky Express | Dam and reservoir |
| Alpine Switch | Snowy ski village and lift |
| Summit Tour | Mountain viaduct |
| Last Light | Snowbound summit research station |

Landmarks use native geometric assemblies with the existing PBR material library. Three sites per circuit reserve their full horizontal footprint against the complete road curve. Terrain flattens beneath each site; surrounding buildings, rocks and trees avoid those reserved footprints. No additional third-party model license is introduced. These landmarks still need artist refinement and richer integration into the surrounding streetscape.

## Build 18 — terrain and complete architecture

The coastal concept in `concepts/coastal-direction.png` is generated reference art, not a game capture. Its prompt and tool provenance are saved beside it. Translate its irregular ridgelines, coherent plaster/tile architecture and layered vegetation into real geometry; never use it as an App Store screenshot.

The runtime now has 72-by-72 sampled ridge meshes with domain-warped spines, erosion detail and calculated surface normals. A Metal surface modifier blends metre-scaled rock projections across three axes so steep slopes retain texture density. Broad color variation breaks repetition; vegetation follows shallow slopes and snow follows upward-facing high ground. Distant ridges do not cast shadows into the near-field map. Coastal ridges stay inland, leaving the sea horizon open.

Coastal streets use three original villa variants with sealed gable roofs, PBR terracotta, ridge caps, plaster cornices, window frames, shutters/louvers, balcony railings, chimneys, sealed stone bases and courtyards. Chalet and ski-village roofs use the same closed prism construction, replacing the two intersecting slabs. Facades now face the track. Terrain normals follow the actual relief instead of all pointing straight up.

Poly Haven CC0 2K rock/tile textures, a 2K daylight sky background, a fir with simplified branches and 466 alpha-cutout canopy fronds, and an 18K-face shrub derivative are bundled. The fir fronds preserve the source needle distribution; blind decimation of disconnected needles erased its canopy and was rejected after render inspection. The existing normalized coast HDR remains the image-based lighting source; the new sky is background only. The rock shader uses a constant roughness of 0.94; the downloaded rock roughness map is retained as source material. Attribution and download hashes are in AssetCredits.txt and `environment-build18-assets.json`. Markings and barriers are combined into static geometry to reduce draw submissions. Vegetation and buildings retain separate scene bounds for culling and clearance checks.

Remaining art gap: these are improvements to the existing SceneKit world, not Asphalt-level scene production. Trackside composition, distant terrain transitions, remaining procedural landmarks, water, imported city facades, foliage silhouettes and vehicle art still need further art direction and player review. Resolution alone does not solve those issues.
