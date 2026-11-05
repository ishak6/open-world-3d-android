# Village Frontier

Offline 3D open-world Android exploration game prototype, built with Godot 4.4.1.

## Current build features

- Deterministic, seed-based procedural world streaming.
- 64 m × 64 m terrain chunks; 7 × 7 active area around the player (49 chunks).
- Distant chunks unload and regenerate from the same seed and coordinates.
- Biome regions: grassland, meadow, forest, highland and dryland.
- Starter village preserved near spawn: houses, paths, river visual, bridge and crop plots.
- Third-person movement with touch joystick, right-side camera drag, hold-to-run, jump, camera reset and pause.
- Procedural humanoid placeholder character with head, eyes, torso, arms and legs.
- Basic procedural walk/run limb animation.
- Character Studio UI: skin tone, hair color and shirt color cycling with local appearance save.
- Schematic world map UI with village, river, forest, hills, fields and player marker.
- Desktop keyboard movement and right-mouse camera control.
- Android-oriented Godot GL Compatibility renderer.

## World streaming

The world is generated offline from seed `481516`. Chunk coordinates determine biome and vegetation placement, so revisiting an area recreates the same layout. Only nearby chunks remain active. This supports effectively unbounded exploration in any direction, limited by device performance and memory; it does not keep infinite terrain in memory.

Chunk size is 64 metres. The game loads a 7 × 7 region around the player and unloads chunks beyond a 4-chunk distance. Terrain is currently flat per chunk; biome materials, vegetation and landmark meshes provide environmental variety. The river is visual only, not a swimming system.

## Controls

- Left virtual joystick: move.
- Drag on the right half of the screen: rotate camera.
- RUN: hold to sprint.
- JUMP: jump.
- CAM: reset camera.
- Top-right pause button: pause/resume.
- Desktop: arrow keys, right mouse drag, Space to jump, Shift to run, Escape to pause.

## Build Android APK

1. Open the **Actions** tab.
2. Select **Build Android APK**.
3. Run the workflow with **Run workflow**, or push a commit to `main`.
4. Wait for all steps to pass.
5. Download the `VillageFrontier-Android-debug` artifact from the successful run.

The workflow uses Godot 4.4.1, matching official Android export templates, Java 17 and Android SDK 35. It runs a headless main-scene smoke test, validates the APK archive and ARM64 native library, and verifies APK signing.

## Android package

- Application name: Village Frontier
- Package ID: `com.ishak6.villagefrontier`
- ABI: `arm64-v8a`
- Build type: debug-signed APK

## Current limitations

This is an expanded prototype, not a finished commercial open-world game. The character is still a primitive-mesh prototype rather than a production rigged asset. Advanced face/hair/clothing customization, full animation clips, surveyed minimap, true heightmap terrain, designed city/ocean, NPCs, missions, inventory gameplay, world save/load, vehicles, sound, swimming, interior interactions and complete day/night/weather systems remain unfinished. Device-specific frame-rate and touch testing still needs to be performed on a physical Android phone.

## Project structure

- `project.godot` — engine and application settings.
- `export_presets.cfg` — Android export configuration.
- `scenes/main.tscn` — main scene.
- `scripts/main.gd` — procedural chunk streaming, biome scenery, player and touch UI.
- `.github/workflows/android-build.yml` — automated Android build and APK verification.
- `assets/icon.svg` — application icon source.
