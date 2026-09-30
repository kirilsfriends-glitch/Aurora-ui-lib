# Aurora Drift 3D

A tiny mobile 3D collectathon built with Godot 4.3.

## Objective

Pilot an aurora drone around a floating arena, collect all 10 energy shards, dodge moving barriers, and enter the activated portal. Falling or touching a barrier returns the drone to the latest safe spawn point without removing collected shards.

## Controls

- **Android:** on-screen direction pad and `JUMP` button.
- **Desktop:** `WASD` or arrow keys to move, `Space` to jump, `R` to restart.

## Run locally

```bash
godot --path game
```

For a headless project validation:

```bash
godot --headless --path game --editor --quit
```

## Android build

The GitHub Actions workflow uses the `barichello/godot-ci:4.3` image with matching Godot 4.3 export templates, JDK, Android SDK, and debug keystore:

```bash
godot --headless --export-debug "Android" ../build/android/AuroraDrift3D-v0.1.0-debug.apk
```

The resulting APK is published as a GitHub Release asset together with its SHA-256 checksum.
