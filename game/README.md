# Aurora Strike vertical slice — Godot project

This is the focused 0.3 source-build alpha of Aurora Strike for Godot 4.7.2 GL Compatibility rendering.

## Current playable content

### Dockyard / Night

A manually arranged three-lane 5v5 map:

- north and south container routes for rifles and flanks;
- a central Customs block with two short rotations;
- protected team staging yards;
- symmetric travel timing with asymmetric environmental detail;
- waist-height ballistic cover and hard container cover;
- authored location callouts used by the HUD;
- a dense AStar waypoint graph and more than 60 cover candidates;
- wet industrial materials, rain, crane silhouettes, cold/warm work lights, and ambient dock audio.

### Team Deathmatch

Alpha and Bravo deploy five operators each. The first squad to 30 eliminations wins. Eliminated combatants redeploy after 3.2 seconds.

### Active loadouts

- AK-47 — heavy damage and stronger recoil;
- M4A1 — lower recoil and faster follow-up shots;
- AWP — slow high-caliber precision rifle with scoped ADS;
- Glock-18 — fast, mobile close-range sidearm.

Only these four weapons are exposed by the rebuilt lobby. Older database entries are retained for later development, not represented as finished content.

## Controls

### Android

Each finger keeps an independent role until release:

- floating left stick — movement;
- drag in free right-side space — camera;
- **FIRE** — shoot;
- **ADS** — aim or scope;
- **JUMP** — jump;
- **DUCK** — crouch while held;
- **R** — reload;
- **SWAP** — cycle the four test loadouts.

### Desktop validation

- `WASD` — movement;
- mouse — camera;
- left mouse — fire;
- right mouse — ADS;
- `Space` — jump;
- `C` — crouch;
- `R` — reload;
- `Q` — cycle active weapons;
- `Esc` — release mouse capture.

## Main systems

- `scripts/dockyard_map.gd` — authored collisions, lighting, rain, ambience, callouts, AStar and cover graph.
- `scripts/game.gd` — focused TDM lifecycle, teams, scoring, redeployment, effects and damage policy.
- `scripts/lobby.gd` — cinematic briefing and four-weapon loadout selection.
- `scripts/hud.gd` — score bar, location, objective, health/ammo panels, kill feed and combat feedback.
- `scripts/player_controller.gd` — FPS movement, crouch, ADS, camera bob/sway, recoil and health.
- `scripts/bot_controller.gd` — perception, hearing, investigation, routing, cover and combat states.
- `scripts/weapon_controller.gd` — hitscan, accuracy, headshots, audio, reload, recoil animation and effects.
- `scripts/touch_fps_controls.gd` — independent multitouch role tracking.

## Validation

```bash
godot --headless --editor --quit --path game
godot --headless --path game --script res://tests/shooter_smoke_test.gd
```

The smoke test loads the real entry scene and deploys all ten combatants. Android CI publishes the validated APK as an explicitly labeled alpha pre-release for hands-on device testing.
