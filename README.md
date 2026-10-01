# Aurora UI Library + Aurora Drift 3D

This repository contains the original Lua UI library (`Source.lua`) and **Aurora Drift 3D**, an offline Godot 4.3 campaign for Android and desktop.

## Aurora Drift 3D v0.4.2

Pilot a Blender-modelled aurora drone through **ten** increasingly difficult neon sectors:

1. **Aurora Garden** — movement, jumping, shards, and patrol sentinels;
2. **Shifting Isles** — moving platforms and launch pads over the void;
3. **Polarity Reactor** — beacons, wind tunnels, and rotating lasers;
4. **Event Horizon** — low gravity, disappearing platforms, and a countdown;
5. **Gravity Archipelago** — gravity wells that curve jumps between islands;
6. **Nova Circuit** — synchronized pulse gates and acceleration lanes;
7. **Radiant Relay** — crossing currents, four relays, gates, and laser patrols;
8. **Fractured Ascent** — an elevated remix of moving, vanishing, and gravity platforms;
9. **Chromatic Tempest** — a timed high-density survival arena;
10. **Aurora Apex** — a final convergence of the campaign's mechanics.

The later sectors deliberately remix existing systems instead of introducing a new rule every time. Difficulty rises through denser combinations, faster hazards, more objectives, vertical routes, low gravity, and stricter timers.

### Visibility and fair hazards

Version 0.4.2 adds a global shadow-free fill light for wide arenas. Red sentinels move at constant speed without pausing at patrol endpoints, and their hitboxes now match the visible model. Rotating beams have visible matching collision and a safe central hub; pulse-gate collision switches off with the visual. Ultrawide fullscreen, brighter gradients, procedural emissive floors, and balanced Blender colors are retained.

### Controls and performance

The mobile interface uses a floating analog stick and independently tracked multitouch zones. Movement, jumping, and camera orbit work simultaneously. Desktop controls support `WASD`, mouse orbit, mouse-wheel zoom, and `Q` / `E` camera rotation. Movement is always camera-relative.

Rendering remains mobile-focused: billboard stars, one optimized render mesh per Blender asset, shared resources, limited dynamic lights, and FSR reconstruction reduce CPU/GPU load.

All seven primary game objects are original assets generated with **Blender 4.3**. Reproducible source and export tooling live in [`tools/generate_models.py`](tools/generate_models.py) and [`assets/blender/`](assets/blender/).

The Godot project is in [`game/`](game/). See [`game/README.md`](game/README.md) for full controls and local run instructions.

### Android APK

GitHub Actions imports the Blender-generated GLB assets, smoke-tests all ten levels, exports an arm64 Android APK with Godot 4.3, validates its signature and native library, and publishes it under this repository's **Releases** page. A SHA-256 checksum is included beside the APK.

The game works offline and requests no sensitive Android permissions.
