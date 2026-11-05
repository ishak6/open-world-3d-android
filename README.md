# Village Frontier

Offline 3D open-world Android exploration game prototype, built with Godot 4.4.1.

## Selected technical target

- Graphics profile: **Medium** — 25 active chunks, 16 × 16 terrain grid per chunk, reduced shadow distance and mobile GL Compatibility renderer.
- Visual style: **Hybrid** — height-based procedural terrain, biome color palettes, atmospheric lighting/fog, and optimized procedural environment meshes.
- World size: **Infinite-style procedural streaming** — deterministic seed-based chunks are generated around the player in every direction and unloaded behind the player. The world is not held in memory all at once.

## Current build features

- Deterministic world seed: `481516`.
- 64 m × 64 m world chunks.
- 5 × 5 active chunk window (25 chunks); chunks outside the 2-chunk active radius are unloaded.
- Continuous height sampling in global world coordinates, so terrain heights line up at chunk borders.
- Terrain collision is generated from the same mesh used for rendering.
- Starter village region is flattened smoothly to preserve houses, paths, bridge and crop plots.
- Biomes: grassland, meadow, forest, highland and dryland.
- Vegetation follows terrain height; trees are batched per chunk with MultiMesh to reduce draw calls.
- Third-person movement with touch joystick, right-side camera drag, hold-to-run, jump, camera reset and pause.
- Procedural humanoid placeholder with AnimationPlayer clips for idle, walk, run and jump; limbs rotate from shoulder/hip pivot nodes.
- Character Studio prototype: skin tone, hair color and shirt color cycling with local appearance save.
- Schematic exploration map UI.
- Android-oriented Godot GL Compatibility renderer.
- Runtime day/night cycle with changing sun energy, sky colors and ambient light.
- Weather selector: clear, rain (local GPU rain particles) and mist/fog.
- Animated river surface using a lightweight water shader.
- Procedural terrain micro-variation shader for hybrid surface detail.
- Village prototype details: gable roofs, doors, windows, chimneys, lamps and three decorative resident NPCs.
- Character placeholder details: ears, nose, neck, shoes and backpack.

## World generation

The terrain generator samples noise using absolute world coordinates rather than chunk-local coordinates. This is important: adjacent chunks receive matching edge heights. The village spawn area blends smoothly into the procedural terrain rather than creating a sharp flat-to-hill boundary.

Each chunk contains a 16 × 16 terrain grid (17 × 17 sampled corners). The medium profile currently keeps a 5 × 5 region active. This reduces the previous 7 × 7 active region from 49 chunks to 25 chunks. A deterministic coordinate-based random seed controls biome props so unloaded regions regenerate consistently.

The world is procedurally expandable in all directions, but device performance, available memory, coordinate precision and content variety remain practical limits. Infinite streaming does not mean infinite memory or unlimited handcrafted content.

## Visual direction: hybrid

- Natural terrain height and elevation shading.
- Biome-specific ground palettes.
- Procedural tree, rock and landmark placement.
- MultiMesh batching for tree trunks and crowns.
- Atmospheric sky and fog with mobile-conscious shadow distance.
- GL Compatibility renderer for broad Android support.

## Controls

- Left virtual joystick: move.
- Drag on the right half of the screen: rotate camera.
- RUN: hold to sprint.
- JUMP: jump.
- CAM: reset camera.
- CHARACTER: open the appearance prototype.
- MAP: open the schematic exploration map.
- Top-right pause button: pause/resume.
- Desktop: arrow keys, right mouse drag, Space to jump, Shift to run, Escape to pause.

## Android build

1. Open the **Actions** tab.
2. Select **Build Android APK**.
3. Run the workflow with **Run workflow**, or push a commit to `main`.
4. Wait for the headless scene smoke test, APK archive validation and signing verification to pass.
5. Download the `VillageFrontier-Android-debug` artifact from the successful run.

The workflow uses Godot 4.4.1, matching Android export templates, Java 17 and Android SDK 35. The output is a debug-signed ARM64 APK.

## Known limitations — not yet complete

- The player is a primitive-mesh placeholder, not a production-quality rigged character.
- Character customization changes selected colors only; face shape, hairstyles, body proportions and modeled clothing are not implemented.
- Character motion uses procedural pivot-based AnimationPlayer clips; it is not a skeletal rig or motion-captured animation library.
- The map is a schematic panel, not a live surveyed minimap or full world atlas.
- Terrain is low-resolution procedural height mesh; it is not a detailed sculpted landscape.
- The starter village remains a small procedural prototype; a large designed city, detailed road network, ocean/coastline, interiors and generated-river bridges are not complete.
- Village residents are decorative idle prototypes without navigation, dialogue or schedules.
- Rain is a local visual particle effect; there is no wet-surface simulation, thunder audio or puddle system.
- Water has animated surface shading but no swimming, buoyancy, current simulation or water physics.
- NPC AI, animals, vehicles, missions, inventory gameplay, world save/load, audio and swimming are not complete.
- Physical Android device tests are still required for touch layout, thermal behavior, memory and sustained FPS.

## Project structure

- `project.godot` — engine and application settings.
- `export_presets.cfg` — Android export configuration.
- `scenes/main.tscn` — main scene.
- `scripts/main.gd` — world streaming, player, scenery and HUD.
- `scripts/world/terrain_generator.gd` — continuous height sampling and chunk terrain mesh generation.
- `.github/workflows/android-build.yml` — automated Android build and APK verification.
- `assets/icon.svg` — application icon source.
- `docs/TECHNICAL_DESIGN.md` — technical architecture and implementation plan.
