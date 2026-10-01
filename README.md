# Aurora Strike: Mobile

Aurora Strike is being rebuilt from scratch as a mobile-first 3D FPS in **Unity 6 and C#**. The old Aurora Drift experience and the rejected broad prototype are not used by the Android Unity build.

## Current Unity vertical slice

The active project is [`unity-probe/`](unity-probe/) (the directory name is retained because the Unity Build Automation target already points to it). It now contains the actual C# gameplay slice rather than the earlier toolchain cube:

- bright daytime **Dockyard** combat arena with warehouses, containers, customs building, cranes, cover and three readable lanes;
- complete **5v5 Team Deathmatch** loop with score limit, timer, deaths and respawns;
- local first-person controller with movement, jump, recoil, ADS, weapon sway and animated reload pose;
- independently tracked multitouch roles for move, look, fire, ADS, jump, reload and weapon swapping;
- firing is accepted **only** from the dedicated FIRE control on Android—ordinary look/movement touches cannot trigger a shot;
- persistent control settings for sensitivity, button scale, classic/compact/left-handed layouts, aim assist and inverted Y;
- tactical C# bots with perception, reaction delay, A* routing, patrol/hunt/combat/cover states, strafing, retreat, separation and friendly-fire checks;
- articulated operator rigs with procedural walk/aim animation;
- AK-47, M4A1, AWP and Glock-18 authored in the original Blender source and converted to Unity-compatible OBJ resources;
- a custom mobile shader referenced directly by the scene, avoiding the magenta stripped-shader issue found by the cloud smoke build;
- mobile HUD with score, timer, location, health, ammo, crosshair, hit/headshot marker and kill feed.

This remains an **alpha vertical slice**, not the final promised five-map/twelve-weapon game. Device testing and iteration come before expanding content.

## Unity cloud build

Unity Build Automation is configured for:

- branch: `arena/01a0f376-aurora-ui-lib`
- project directory: `unity-probe`
- Unity: `6000.3.24f1`
- Android application ID: `ai.arena.aurorastrike`
- scene: `Assets/AuroraStrike.unity`

The first cloud APK proved that the Unity/Android toolchain works. A new build is required after gameplay changes to validate compilation, runtime rendering, controls and performance on a real device.

## Original art pipeline

- Blender source: [`assets/blender/aurora_strike_assets.blend`](assets/blender/aurora_strike_assets.blend)
- Blender generator: [`tools/generate_shooter_models.py`](tools/generate_shooter_models.py)
- dependency-free Unity converter: [`tools/convert_glb_to_unity_obj.py`](tools/convert_glb_to_unity_obj.py)
- Unity runtime weapon models: `unity-probe/Assets/Resources/Models/`

No downloaded models, textures, or audio samples are used in this slice.

## Legacy reference implementation

The previous Godot vertical slice remains under [`game/`](game/) only as a functional design/reference implementation while systems are ported. It is not included in the Unity Android build.
