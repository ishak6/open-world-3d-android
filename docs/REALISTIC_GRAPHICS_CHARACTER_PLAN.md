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
