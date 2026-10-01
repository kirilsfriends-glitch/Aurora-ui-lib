# Aurora Strike: Mobile — Godot Project

Aurora Strike is a mobile-focused 5v5 offline FPS built with Godot 4.3 GL Compatibility rendering.

## Game flow

The opening operations lobby allows the player to choose a mode and bot difficulty, then vote on one of five maps. Nine simulated bot votes are randomized for each lobby. The highest-voted map wins; tied votes are resolved randomly.

- **Team Deathmatch:** first team to 40 eliminations, with three-second respawns.
- **Elimination:** no mid-round respawns; first team to win five rounds wins the match.
- **Control:** occupy the center zone uncontested; first team to 100 points wins.

Each match contains the local player, four Alpha teammates, and five Bravo opponents.

## Controls

### Android multitouch

Every touch is independently assigned and retained until release, so actions can overlap:

- floating left stick — movement;
- drag on unoccupied right-side space — camera aim;
- **FIRE** — shoot (hold for automatic weapons);
- **ADS** — aim down sights / scope;
- **JUMP** — jump;
- **DUCK** — crouch while held;
- **R** — reload;
- **SWAP** — cycle through all twelve weapons.

### Desktop test controls

- `W`, `A`, `S`, `D` — move;
- mouse — aim;
- left mouse — fire;
- `Space` — jump;
- `R` — reload;
- `Q` — cycle weapon;
- `Esc` — release the mouse cursor.

## Systems

- `scripts/game.gd` — match lifecycle, teams, modes, scoring, rounds, respawns, effects, and damage policy.
- `scripts/lobby.gd` — operations UI and player/bot map voting.
- `scripts/player_controller.gd` — first-person movement, camera, crouch, ADS, health, and loadout.
- `scripts/bot_controller.gd` — perception, hearing, tactical states, AStar routing, cover, combat, and skill scaling.
- `scripts/weapon_controller.gd` — hitscan, shotgun pellets, headshots, reloads, recoil, grenades, and model mounting.
- `scripts/weapon_database.gd` — authoritative statistics for the twelve launch weapons.
- `scripts/map_library.gd` — five map layouts, palettes, spawns, obstacles, and objectives.
- `scripts/map_builder.gd` — optimized procedural geometry and waypoint/cover graph generation.
- `scripts/touch_fps_controls.gd` — independent mobile touch-role tracking.
- `scripts/hud.gd` — match score, timer, kill feed, hit feedback, health, ammunition, and objectives.

The map renderer uses shared primitive resources, low-cost materials, baked procedural layouts, shadow-free directional lighting, and 0.85 3D scaling for stable mobile performance. Detailed Blender assets are reserved for weapons, operators, and high-value props.

## Validation

With Godot 4.3 available:

```bash
godot --headless --editor --quit --path game
godot --headless --path game --script res://tests/shooter_smoke_test.gd
```

The CI smoke test verifies 12 weapon definitions, five maps, ten spawn sets, tactical cover, and AStar routes before Android export.
