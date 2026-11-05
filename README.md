# Village Frontier

Offline 3D open-world exploration prototype for Android, built with Godot 4.4.1.

## Current prototype

- Procedurally generated village, grassland, river, bridge, forest and crop fields.
- Third-person player controller.
- Touch joystick, camera-look drag, run and jump controls.
- Keyboard movement for desktop testing.
- Android arm64 debug APK exported by GitHub Actions.

## Build

1. Open the **Actions** tab.
2. Select **Build Android APK**.
3. Run the workflow with **Run workflow**, or push a commit to `main`.
4. Wait for all steps to pass.
5. Download the `VillageFrontier-Android-debug` artifact from the successful run.

The workflow uses Godot 4.4.1, matching official Android export templates, Java 17 and the Android SDK. It validates APK archive integrity, required Android files and APK signing before uploading the artifact.

## Android package

- Application name: Village Frontier
- Package ID: `com.ishak6.villagefrontier`
- ABI: `arm64-v8a`
- Build type: debug-signed APK

## Known prototype limitations

This is an early playable prototype, not a finished open-world game. NPCs, missions, inventory, save/load, vehicles, player animation, audio, minimap, pause/settings screens and interior interactions are not implemented yet. The river currently has visual geometry only and should not be treated as a swimming system.

## Project structure

- `project.godot` — engine and application settings.
- `export_presets.cfg` — Android export configuration.
- `scenes/main.tscn` — main scene.
- `scripts/main.gd` — procedural world, player, camera and touch UI.
- `.github/workflows/android-build.yml` — automated Android build and APK verification.
- `assets/icon.svg` — application icon source.
