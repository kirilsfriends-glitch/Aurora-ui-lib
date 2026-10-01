# Aurora Strike Unity project

Unity 6000.3.24f1 Android project used by Unity Build Automation.

## Runtime architecture

The committed `Assets/AuroraStrike.unity` scene contains one bootstrap component and a direct reference to `Aurora/MobileLit`. Runtime systems are authored in C# and build the focused Dockyard slice deterministically:

- `AuroraGame.cs` — match lifecycle, 5v5 deployment, score and respawn flow;
- `DockyardMap.cs` — daylight arena geometry, collision, cover data and A* grid;
- `PlayerController.cs` / `MobileControls.cs` — FPS locomotion and independent touch roles;
- `TacticalBot.cs` / `OperatorRig.cs` — tactical state machine, movement and animation;
- `WeaponController.cs` — four tuned weapons, Blender models, hitscan, reload, recoil and effects;
- `AuroraHud.cs` — mobile HUD, feedback and persistent control settings;
- `AuroraMobileLit.shader` — explicitly referenced mobile shader.

`Assets/Editor/BuildProbe.cs` remains as an optional automation entry point, but standard Unity Build Automation builds use `ProjectSettings/EditorBuildSettings.asset` and do not require a custom method.

## Android input safety

On Android, `PlayerController` never treats Unity's emulated mouse button as fire because it may be synthesized from arbitrary touches. Only a touch that begins inside the visible FIRE control can set the firing state.

## Art provenance

The weapon OBJ/MTL resources are deterministic conversions of the original Blender-authored GLB exports. Regenerate them from the repository root with:

```bash
python3 tools/convert_glb_to_unity_obj.py
```
