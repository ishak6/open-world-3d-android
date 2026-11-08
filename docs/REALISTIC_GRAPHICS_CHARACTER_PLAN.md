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
| Realistic Water | Mobile-compatible water shader/material with Fresnel response, layered animated wave normals and shoreline treatment | GL Compatibility Android render test; no unsupported renderer-only shader features | PARTIAL: layered animated waves, normal response and Fresnel added; depth tint/shoreline and device validation remain |
| Spatial Audio | Active 3D audio listener, positional environment emitters, attenuation and bus/mix design | Listener + emitter test scene and headphone/device test | PARTIAL: active camera listener added; emitters/mix/tests remain |
| Android FPS Testing | Runtime FPS/frame-time telemetry plus repeatable device test matrix | Actual Android device captures for target quality profiles and sustained test | PARTIAL: live FPS/frame-time HUD added; device measurements remain |
| Android performance budgets | Quality presets, chunk/vegetation budgets, thermal and memory checks | Low/mid/high device reports, sustained 10-minute run | OPEN |

### Runtime changes in this update
- Added an `AudioListener3D` under the active gameplay camera so 3D audio emitters can be spatialized relative to the player camera.
- Added a half-second rolling FPS and frame-time HUD sample. This is runtime telemetry, not proof of a measured device benchmark.
- Upgraded the starter-village water shader with layered animated wave motion, fragment normal variation, Fresnel edge response and lower roughness; depth-based tint, shoreline foam/transition and Android visual validation remain open.
- No unlicensed or fabricated human/tree asset has been inserted. The current procedural human and vegetation remain fallback placeholders until suitable licensed assets are imported.

### Required Android test matrix
- Low tier: 4 GB RAM / entry-level supported GPU, 30 FPS target.
- Mid tier: 6 GB RAM / mainstream GPU, stable 30–45 FPS target.
- High tier: 8 GB+ RAM / stronger GPU, 45–60 FPS target where thermals permit.
- Capture average FPS, 1% low (external profiler), frame time, memory, thermal state, chunk transition hitching, audio latency and battery drain.
- Run at least 10 minutes per tier after warm-up; repeat in clear, rain and night conditions.

## Latest verified CI evidence (2026-11-08)

- Workflow run: [Run #90](https://github.com/ishak6/open-world-3d-android/actions/runs/42506606409)
- Commit: `fd4d3be8f8a100c094ddc4a5cacfe4ac2032bd2c` — fixed a missing closing parenthesis in the water shader's generated normal expression.
- Godot resource import: PASS.
- Main-scene headless smoke test: PASS.
- Android debug APK export: PASS.
- APK archive integrity and Android manifest/native library checks: PASS.
- APK signature verification: PASS.
- Artifact `VillageFrontier-Android-debug` uploaded (artifact ID `13627388987`, approximately 25.7 MiB; expires 2026-11-22).
- Workflow job steps and artifact upload completed successfully. GitHub still reported the run as `in_progress` during final container cleanup when checked; do not label the workflow conclusion final until GitHub reports `completed/success`.
- These checks establish import, headless startup and APK packaging only. They do not establish visual correctness on a physical Android device, sustained FPS, thermal stability, or photorealistic asset quality. Those acceptance items remain OPEN/PARTIAL as listed above.

## Asset sourcing research (2026-11-08) — candidates, not yet imported

The repository currently contains no GLB/GLTF character or tree assets. The following sources were checked as potential legal inputs; none is counted as integrated until the actual downloaded files, licence evidence and Godot import tests are committed.

- **Human generation candidate — Ara 3D Gen:** https://ara3dgen.com/ . Its published page describes realistic MakeHuman-based characters, detail levels from approximately 5k to 120k triangles, GLB/FBX/OBJ export, Mixamo-named rigs, face bones, blend shapes and 117 animations. The project code is published under MIT; character data is described as CC0 MakeHuman data and motion capture is attributed to CMU Graphics Lab. Candidate for producing the hero model, subject to checking the exact exported asset metadata/licences and Android material compatibility. It is a generator, not a prebuilt project asset.
- **Tree candidate — Polyy.AI 3D Deciduous Trees Pack:** https://polyyai.itch.io/3d-deciduous-trees-pack . The publisher lists 14 GLB trees with PBR textures and CC0 1.0, but the download is approximately 116 MB. Candidate only; select a small subset, inspect texture dimensions/triangle counts, create LODs and profile on Android before shipping.
- **Rejected for the realistic hero requirement:** low-poly CC0 packs such as Gobkit Freebies provide rigged GLBs but are explicitly low-poly/baked-color assets; they may serve as distant NPC placeholders, not as the realistic close-up player character.

### Asset import gate
1. Obtain the actual GLB/GLTF and its licence file/source page record.
2. Inspect mesh triangle count, skeleton hierarchy, animation tracks, UVs, texture channels and texture sizes.
3. Import in the project's Godot 4.4.1 GL Compatibility pipeline; resolve unsupported materials/features.
4. Add LODs and texture budgets before placing assets in streamed chunks.
5. Run import + headless smoke + Android export, then validate the asset visually on a physical Android device.

**Current status remains BLOCKED:** research identified plausible sources, but no binary asset has yet been downloaded, reviewed or committed to this repository.

## Android quality profile implementation (2026-11-08)

- Added a graphics-profile selector to the pause menu: HIGH → MEDIUM → LOW → HIGH.
- The selected profile is saved in `user://world.cfg` and restored on next launch.
- HIGH keeps full detail density, directional shadows to 84 m and 420 rain particles.
- MEDIUM scales grass/shrub detail instances to 72%, keeps shadows with a 56 m distance and uses 260 rain particles.
- LOW scales grass/shrub detail instances to 45%, disables directional shadows and uses 120 rain particles.
- Switching profiles rebuilds currently streamed chunks so the vegetation density takes effect immediately.
- This is an initial adaptive-quality control, not a completed device-adaptive system. Terrain resolution, chunk load radius, texture/LOD budgets and thermal adaptation are not yet profile-controlled. Actual Android FPS/memory/thermal measurements remain OPEN.
