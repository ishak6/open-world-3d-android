# Village Frontier — Realistic Graphics & Character Implementation Plan

## Locked direction
- Visual style: Realistic AAA-inspired 3D (not literal 5D/8D rendering).
- World: Bangladesh-inspired village, river, paddy fields and tropical vegetation blended with international forests, highlands and valleys.
- Priority: Visual quality first, with Android performance budgets and scalable quality settings.

## Current repository audit (2026-11-08)
- Renderer: Godot 4 GL Compatibility/mobile renderer.
- World: procedural chunk terrain using FastNoiseLite and SurfaceTool.
- Terrain: mesh resolution was 20; village center is flattened; terrain uses a simple vertex-color material.
- Vegetation: MultiMesh batching exists, but grass uses capsule meshes and shrubs use sphere meshes; density was low.
- Character: procedural primitive meshes in scripts/main.gd, not a production human model and without a skinned human skeleton or realistic facial deformation.
- Lighting: procedural sky, directional light, fog, rain particles and day/night cycle already exist.
- Missing production assets: no rigged human GLB/GLTF, authored PBR texture sets, detailed tree/leaf assets or realistic water/environment asset pack.
- A successful CI build proves export only; it does not prove visual quality or device performance.

## Implementation phases and acceptance criteria

### Phase 1 — Rendering and terrain foundation (started)
- Raise terrain mesh resolution from 20 to 32.
- Set HIGH graphics target and REALISTIC visual-style label.
- Increase deterministic grass/shrub instance counts while retaining MultiMesh batching.
- Acceptance: chunk seams checked, scripts parse, Android GPU/memory/FPS measured.

### Phase 2 — Character replacement (critical blocker)
- Replace primitive humanoid with a licensed realistic rigged GLB/GLTF human asset.
- Required: anatomical proportions, detailed face/eyes/ears/hair, five-finger hands, PBR skin/clothing textures, skeleton and animation retargeting.
- Animations: idle, walk, run, sprint, jump, land, crouch, swim and climb.
- Acceptance: close-up and full-body screenshots, animation inspection, no missing materials or broken skinning.
- This phase is not complete until a real asset is added and tested.

### Phase 3 — World asset quality
- Replace placeholder trees/shrubs with authored trunk/branch/leaf meshes and varied foliage.
- Add ground material sets (albedo/normal/roughness), grass blade meshes, rocks, mud, wet soil, crop rows, village architecture and fences.
- Add riverbank geometry and water shader with reflections/ripples/shoreline transitions.
- Acceptance: biome screenshot set and chunk-boundary inspection.

### Phase 4 — Lighting and immersion
- Tune sunlight, ambient fill, contact shadows, fog distance and exposure.
- Add weather transitions, wet-surface response, spatial ambience and environmental audio.
- Acceptance: daylight, sunrise/sunset, night, rain and mist screenshots.

### Phase 5 — Android quality/performance
- Add High/Medium/Low profiles, texture import budgets, LOD, visibility/occlusion strategy and chunk streaming budgets.
- Measure frame time, memory and thermal behavior on target Android devices.
- Acceptance: no crash, no runaway memory growth, stable frame pacing and documented device tests.

## Current scope
Only Phase 1 foundation changes are applied in this update. Phases 2–5 remain open work; no claim of photorealism is made until the required assets and device validation exist.


## Expanded requested deliverables (2026-11-08)

The following nine deliverables are now tracked as explicit acceptance items. A checklist item is not considered complete merely because a placeholder or primitive mesh exists.

| Deliverable | Required implementation | Acceptance evidence | Status |
|---|---|---|---|
| Realistic Human Model | Licensed, production-quality human GLB/GLTF with complete materials and facial/body detail | Asset license + import report + in-game close-up | BLOCKED: asset not present |
| Human Skeleton Rig | Deformable humanoid skeleton, weighted mesh, retargetable animation set | Skeleton inspection, deformation test, walk/run/jump/idle retarget test | BLOCKED: rigged model not present |
| PBR Skin & Clothing | Base color, normal, roughness, AO and (where supported) subsurface/skin response; clothing material sets | Texture-channel inspection and mobile-renderer visual test | BLOCKED: authored PBR sets not present |
| Realistic Trees | Detailed trunk/branch/leaf meshes, LODs, wind response and collision policy | Close/medium/far screenshots and Android frame-time profile | BLOCKED: detailed tree assets not present |
| PBR Asset Pack | Licensed terrain, foliage, wood, stone, fabric and environment materials | Asset manifest, license records, import validation | BLOCKED: no complete pack in repository |
| Realistic Water | Mobile-compatible water shader/material with depth tint, Fresnel, animated normals and shoreline treatment | GL Compatibility Android render test; no unsupported renderer-only shader features | OPEN |
| Spatial Audio | Active 3D audio listener, positional environment emitters, attenuation and bus/mix design | Listener + emitter test scene and headphone/device test | PARTIAL: active camera listener added; emitters/mix/tests remain |
| Android FPS Testing | Runtime FPS/frame-time telemetry plus repeatable device test matrix | Actual Android device captures for target quality profiles and sustained test | PARTIAL: live FPS/frame-time HUD added; device measurements remain |
| Android performance budgets | Quality presets, chunk/vegetation budgets, thermal and memory checks | Low/mid/high device reports, sustained 10-minute run | OPEN |

### Runtime changes in this update
- Added an `AudioListener3D` under the active gameplay camera so 3D audio emitters can be spatialized relative to the player camera.
- Added a half-second rolling FPS and frame-time HUD sample. This is runtime telemetry, not proof of a measured device benchmark.
- No unlicensed or fabricated human/tree asset has been inserted. The current procedural human and vegetation remain fallback placeholders until suitable licensed assets are imported.

### Required Android test matrix
- Low tier: 4 GB RAM / entry-level supported GPU, 30 FPS target.
- Mid tier: 6 GB RAM / mainstream GPU, stable 30–45 FPS target.
- High tier: 8 GB+ RAM / stronger GPU, 45–60 FPS target where thermals permit.
- Capture average FPS, 1% low (external profiler), frame time, memory, thermal state, chunk transition hitching, audio latency and battery drain.
- Run at least 10 minutes per tier after warm-up; repeat in clear, rain and night conditions.
