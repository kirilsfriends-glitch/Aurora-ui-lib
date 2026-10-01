# Aurora UI Library + Aurora Drift 3D

This repository contains the original Lua UI library (`Source.lua`) and **Aurora Drift 3D**, an offline Godot 4.3 campaign for Android and desktop.

## Aurora Drift 3D v0.3.0

Pilot a Blender-modelled aurora drone through six neon sectors. Each level introduces a new challenge:

1. **Aurora Garden** — movement, jumping, collectible shards, and patrol sentinels;
2. **Shifting Isles** — moving platforms, launch pads, and precision jumps over the void;
3. **Polarity Reactor** — switch beacons, wind tunnels, and rotating laser arms;
4. **Event Horizon** — low gravity, disappearing platforms, faster hazards, and a countdown;
5. **Gravity Archipelago** — gravity wells that curve the drone's trajectory between islands;
6. **Nova Circuit** — synchronized pulse gates, acceleration lanes, relays, and a timed finale.

### Controls and performance

The mobile interface uses a floating analog stick and independently tracked multitouch zones. Movement, jumping, and camera orbit now work simultaneously. Desktop controls support `WASD`, mouse orbit, mouse-wheel zoom, and `Q` / `E` camera rotation. Movement is always camera-relative.

Version 0.3.0 also introduces an optimized sky and rendering path: billboard stars replace expensive sphere geometry, Blender exports one mobile render mesh per asset, dynamic lights and shadows are reduced, repeated materials/meshes are shared, and 3D rendering uses FSR reconstruction.

All seven primary game objects are original assets generated with **Blender 4.3**. Reproducible source and export tooling live in [`tools/generate_models.py`](tools/generate_models.py) and [`assets/blender/`](assets/blender/).

The Godot project is in [`game/`](game/). See [`game/README.md`](game/README.md) for full controls and local run instructions.

### Android APK

GitHub Actions imports the Blender-generated GLB assets, smoke-tests all six levels, exports an arm64 Android APK with Godot 4.3, validates its signature and native library, and publishes it under this repository's **Releases** page. A SHA-256 checksum is included beside the APK.

The game works offline and requests no sensitive Android permissions.
