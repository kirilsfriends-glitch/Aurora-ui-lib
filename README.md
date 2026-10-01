# Aurora Strike: Mobile — Quality Vertical Slice

Aurora Strike is being rebuilt as a focused offline first-person tactical shooter for Android. The former v0.1.0 prototype and its GitHub Release were withdrawn because they did not meet the requested quality bar.

This branch now prioritizes one complete, testable combat slice instead of advertising unfinished breadth.

## Vertical slice 0.2

- **One authored map:** Dockyard / Night, a rain-soaked three-lane cargo terminal with warehouses, container routes, a central Customs landmark, cranes, spawn shelters, tactical cover, close-range flanks, and long rifle sightlines.
- **Four tuned weapons:** AK-47, M4A1, AWP, and Glock-18.
- **One finished mode:** 5v5 Team Deathmatch to 30 eliminations.
- **Tactical bots:** sight checks, hearing and shot investigation, AStar routing, cover selection, strafing, retreat/reload decisions, separation, friendly-fire avoidance, and skill-based reaction/accuracy.
- **Mobile FPS input:** independently tracked movement, look, fire, ADS, jump, crouch, reload, and weapon-swap touches.
- **Presentation pass:** cinematic briefing art, rebuilt lobby and HUD, rain, cold/warm team lighting, location callouts, kill feed, hit/headshot feedback, weapon recoil/sway, reload poses, muzzle flashes, tracers, and damage feedback.
- **Original sound pass:** weapon reports, reload mechanics, dry fire, UI confirmation, hit/headshot cues, and seamless dock ambience generated procedurally without third-party samples.
- **Original Blender art:** Dockyard, four weapons, and the operator are generated as an editable Blender 4.3 source gallery.

## Art pipeline

- Blender generator: [`tools/generate_shooter_models.py`](tools/generate_shooter_models.py)
- Original audio generator: [`tools/generate_audio.py`](tools/generate_audio.py)
- Blender source: `assets/blender/aurora_strike_assets.blend`
- Runtime models: [`game/models/`](game/models/)
- Authored gameplay layout: [`game/scripts/dockyard_map.gd`](game/scripts/dockyard_map.gd)

No downloaded models, textures, or audio samples are used. The Dockyard briefing background is original generated artwork stored in `game/ui/`.

## Validation policy

Every private test build must:

1. import the authored map, models, UI, and audio in Godot 4.3;
2. verify the four active weapon definitions and assets;
3. validate spawn separation, the cover graph, location zones, and an AStar route across the map;
4. instantiate the actual lobby and deploy a complete 5v5 match;
5. export and signature-check an arm64 Android APK.

CI uploads the result as a short-lived **private workflow artifact only**. It does not publish a GitHub Release. A public APK will return only after hands-on approval of the vertical slice.

The Godot project and controls are documented in [`game/README.md`](game/README.md).
