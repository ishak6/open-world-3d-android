# Village Frontier — Technical Design

## Product target

Offline third-person Android open-world exploration game.

- Graphics: Medium
- Art direction: Hybrid (naturalistic terrain and lighting with optimized stylized environment assets)
- World: deterministic infinite-style procedural streaming
- Engine: Godot 4.4.1
- Language: GDScript
- Android renderer: GL Compatibility
- Target package: com.ishak6.villagefrontier
- Target ABI: arm64-v8a

## Architecture

### World streaming

The world is divided into 64 m × 64 m chunks. The player-centered active window is 5 × 5 chunks (25 active chunks). Chunks farther than a 3-chunk Chebyshev distance are unloaded. Each chunk is regenerated from the world seed and integer chunk coordinates, so revisiting a location reconstructs the same biome and prop layout.

### Terrain generation

`scripts/world/terrain_generator.gd` samples noise in absolute world coordinates. It creates a 16 × 16 quad grid per chunk, generates normals, assigns biome/elevation vertex colors and returns an ArrayMesh. The same mesh is used to create a static concave collision shape. A smooth radial blend keeps the starter village region flat while transitioning to rolling procedural terrain.

The global-coordinate sampling is a seam-control requirement: neighbouring chunks must compute identical heights at shared borders.

### Environment rendering

The Medium profile uses the mobile GL Compatibility renderer, moderate terrain mesh density, a limited active chunk window, reduced shadow distance, fog and biome palettes. Trees are grouped into per-chunk MultiMesh batches to reduce scene nodes and draw calls.

### Player and UI

The existing third-person CharacterBody3D, touch joystick, camera drag, sprint, jump, pause, basic character appearance panel and schematic map remain in the prototype. Character mesh and animation are explicitly placeholders pending production assets.

## Performance budget and validation targets

These are engineering targets, not measured results:

- Keep active terrain chunks at 25.
- Keep terrain grid resolution at 16 × 16 quads per chunk.
- Batch repeated trees with MultiMesh.
- Avoid loading distant chunks.
- Validate sustained 30 FPS on the minimum supported test device before increasing scene density.
- Check memory, thermal behavior, touch input and collision on physical Android hardware.

## Generation invariants

1. Same seed + same chunk coordinate = same biome and prop placement.
2. Adjacent chunk edges use the same world-space height function.
3. Terrain render mesh and collision mesh come from the same generated mesh.
4. The starter village spawn region remains flat enough for current hand-placed structures.
5. Chunk unload must release its scene nodes and collision resources.

## Roadmap

1. Validate generated terrain and Android build.
2. Replace primitive player with a rigged glTF character and animation state machine.
3. Replace schematic map with a live minimap and explored-world atlas.
4. Build designed village districts, roads, forest, mountain, river and coast assets.
5. Add day/night and weather controllers.
6. Add NPC navigation, interaction, inventory, missions and persistent world save.
7. Profile on physical devices and tune the Medium preset.

## Known risks

- Concave terrain collision generation and per-chunk build time must be measured.
- Procedural noise can create slopes unsuitable for roads unless roads receive dedicated flattening/spline data.
- Generated water and river visuals are not yet a navigable water simulation.
- MultiMesh reduces draw calls but does not eliminate overdraw or GPU cost.
- Infinite coordinate growth eventually encounters floating-point precision limits; origin shifting may be required for very long sessions.
- A successful CI export does not prove good mobile FPS or touch usability.
