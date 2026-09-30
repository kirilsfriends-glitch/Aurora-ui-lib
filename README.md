# Aurora UI Library + Aurora Drift 3D

This repository contains the original Lua UI library (`Source.lua`) and **Aurora Drift 3D**, an offline Godot 4.3 campaign for Android and desktop.

## Aurora Drift 3D v0.2.0

Pilot a Blender-modelled aurora drone through four neon sectors. Each level introduces a new challenge:

1. **Aurora Garden** — movement, jumping, collectible shards, and patrol sentinels;
2. **Shifting Isles** — moving platforms, launch pads, and precision jumps over the void;
3. **Polarity Reactor** — switch beacons, wind tunnels, and rotating laser arms;
4. **Event Horizon** — low gravity, disappearing platforms, faster hazards, and a countdown.

The orbit camera supports right-side touch dragging, right/middle mouse dragging, `Q` / `E`, and on-screen camera buttons. Player movement is always relative to the camera.

All seven primary game objects are original assets generated with **Blender 4.3**. Reproducible source and export tooling live in [`tools/generate_models.py`](tools/generate_models.py) and [`assets/blender/`](assets/blender/).

The Godot project is in [`game/`](game/). See [`game/README.md`](game/README.md) for full controls and local run instructions.

### Android APK

GitHub Actions imports the Blender-generated GLB assets, exports an arm64 Android APK with Godot 4.3, validates its signature and native library, and publishes it under this repository's **Releases** page. A SHA-256 checksum is included beside the APK.

The game works offline and requests no sensitive Android permissions.
