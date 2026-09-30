# Aurora UI Library + Aurora Drift 3D

This repository contains the original Lua UI library (`Source.lua`) and a small Godot 4.3 Android game created as a runnable 3D demo.

## Aurora Drift 3D

Pilot a glowing drone through a floating neon arena:

- collect 10 animated aurora shards;
- avoid three moving energy barriers;
- jump and explore using mobile touch controls or a keyboard;
- activate the exit portal and finish as quickly as possible.

The Godot project is in [`game/`](game/). See [`game/README.md`](game/README.md) for controls and local run instructions.

### Android APK

GitHub Actions builds an arm64 Android debug APK with Godot 4.3 and publishes it under this repository's **Releases** page. A SHA-256 checksum is included beside the APK.

The game is offline and requests no sensitive Android permissions.
